import Foundation

actor SimulatedUploadService: UploadService {
    func upload(
        _ file: UploadFile,
        uploadID: UUID,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadReceipt {
        try Task.checkCancellation()
        onProgress(0)

        for step in 1...10 {
            // Simulate work without blocking a thread.
            try await Task.sleep(for: .milliseconds(200))
            try Task.checkCancellation()

            onProgress(Double(step) / 10)
        }

        try Task.checkCancellation()

        return UploadReceipt(
            id: UUID(),
            uploadID: uploadID
        )
    }
}
