import Foundation
@testable import UploadFlow

actor ControlledUploadService: UploadService {
    private var continuation:
        CheckedContinuation<UploadReceipt, any Error>?

    private var startWaiters:
        [CheckedContinuation<Void, Never>] = []

    private(set) var callCount = 0
    private(set) var receivedUploadIDs: [UUID] = []

    func upload(
        _ file: UploadFile,
        uploadID: UUID,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadReceipt {
        callCount += 1
        receivedUploadIDs.append(uploadID)

        return try await withCheckedThrowingContinuation {
            continuation in

            self.continuation = continuation

            let waiters = startWaiters
            startWaiters.removeAll()

            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }

        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func succeed(uploadID: UUID) {
        let pending = continuation
        continuation = nil

        pending?.resume(
            returning: UploadReceipt(
                id: UUID(),
                uploadID: uploadID
            )
        )
    }
    
    func fail() {
        let pending = continuation
        continuation = nil

        pending?.resume(
            throwing: SimulatedUploadError.connectionLost
        )
    }
}

enum SimulatedUploadError: Error, Sendable {
    case connectionLost
}
