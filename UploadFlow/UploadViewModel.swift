import Foundation
import Combine

@MainActor
final class UploadViewModel: ObservableObject {
    @Published private(set) var state: UploadState = .idle

    private let service: any UploadService
    private var uploadTask: Task<Void, Never>?
    private var logicalUploadID: UUID?
    private var activeAttemptID: UUID?

    init(service: any UploadService) {
        self.service = service
    }

    func selectSampleFile() {
        guard uploadTask == nil else { return }

        let file = UploadFile(
            name: "ExampleDocument.pdf",
            sizeInBytes: 250_000
        )

        // A new selection represents a new logical upload.
        logicalUploadID = UUID()
        state = .ready(file)
    }

    func startUpload() {
        // Set up ownership before reaching any suspension point.
        guard uploadTask == nil,
              let uploadID = logicalUploadID else {
            return
        }

        let file: UploadFile

        switch state {
        case .ready(let selected),
             .cancelled(let selected):
            file = selected

        case .failed(let selected, _):
            file = selected

        default:
            return
        }

        let attemptID = UUID()
        activeAttemptID = attemptID

        state = .uploading(
            file: file,
            attemptID: attemptID,
            progress: 0
        )

        let service = service

        uploadTask = Task { [weak self] in
            defer {
                self?.finishAttempt(attemptID)
            }

            do {
                let receipt = try await service.upload(
                    file,
                    uploadID: uploadID,
                    onProgress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.receiveProgress(
                                progress,
                                attemptID: attemptID
                            )
                        }
                    }
                )

                // A service may return despite cancellation.
                try Task.checkCancellation()

                guard let self,
                      self.activeAttemptID == attemptID else {
                    return
                }

                self.state = .succeeded(
                    file: file,
                    receipt: receipt
                )
            } catch {
                guard let self,
                      self.activeAttemptID == attemptID else {
                    return
                }

                if Task.isCancelled || error is CancellationError {
                    self.state = .cancelled(file)
                } else {
                    self.state = .failed(
                        file: file,
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    func cancelUpload() {
        guard case .uploading(let file, _, _) = state,
              let uploadTask else {
            return
        }

        state = .cancelling(file)
        uploadTask.cancel()

        // Keep the handle until the service call actually finishes.
    }
    
    func waitForCurrentUpload() async {
        let task = uploadTask
        await task?.value
    }

    private func receiveProgress(
        _ progress: Double,
        attemptID: UUID
    ) {
        guard activeAttemptID == attemptID,
              progress.isFinite,
              case .uploading(
                let file,
                let stateAttemptID,
                let previousProgress
              ) = state,
              stateAttemptID == attemptID else {
            return
        }

        // Ignore regressions and constrain values to 0...1.
        let nextProgress = max(
            previousProgress,
            min(max(progress, 0), 1)
        )

        state = .uploading(
            file: file,
            attemptID: attemptID,
            progress: nextProgress
        )
    }

    private func finishAttempt(_ attemptID: UUID) {
        guard activeAttemptID == attemptID else { return }

        uploadTask = nil
        activeAttemptID = nil
    }
}
