import Testing
import Foundation
@testable import UploadFlow

@MainActor
struct UploadViewModelTests {
    @Test
    func duplicateStartDoesNotCreateAnotherUpload() async throws {
        let service = ControlledUploadService()
        let viewModel = UploadViewModel(service: service)

        viewModel.selectSampleFile()
        viewModel.startUpload()

        // Wait until the first call is suspended inside the service.
        await service.waitUntilStarted()

        guard case .uploading = viewModel.state else {
            Issue.record("Expected uploading state.")
            return
        }

        // Try starting again while the first call is still active.
        viewModel.startUpload()

        let callCount = await service.callCount
        #expect(callCount == 1)

        // Finish the suspended call so the test leaves no continuation open.
        let uploadIDs = await service.receivedUploadIDs
        let uploadID = try #require(uploadIDs.first)
        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()
    }
    
    @Test
    func successfulUploadStoresReceiptAndAllowsNewSelection() async throws {
        let service = ControlledUploadService()
        let viewModel = UploadViewModel(service: service)

        viewModel.selectSampleFile()

        guard case .ready(let selectedFile) = viewModel.state else {
            Issue.record("Expected ready state.")
            return
        }

        viewModel.startUpload()
        await service.waitUntilStarted()

        let uploadIDs = await service.receivedUploadIDs
        let uploadID = try #require(uploadIDs.first)

        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()

        guard case .succeeded(let file, let receipt) = viewModel.state else {
            Issue.record("Expected succeeded state.")
            return
        }

        #expect(file == selectedFile)
        #expect(receipt.uploadID == uploadID)

        // A new selection is accepted only after the task handle is cleared.
        viewModel.selectSampleFile()

        guard case .ready(let newFile) = viewModel.state else {
            Issue.record("Expected ready state after selecting another file.")
            return
        }

        #expect(newFile.id != selectedFile.id)
    }
    
    @Test
    func cancellationBlocksRetryUntilOldCallFinishes() async throws {
        let service = ControlledUploadService()
        let viewModel = UploadViewModel(service: service)

        viewModel.selectSampleFile()

        guard case .ready(let selectedFile) = viewModel.state else {
            Issue.record("Expected ready state.")
            return
        }

        viewModel.startUpload()
        await service.waitUntilStarted()

        let uploadIDs = await service.receivedUploadIDs
        let uploadID = try #require(uploadIDs.first)

        viewModel.cancelUpload()

        #expect(viewModel.state == .cancelling(selectedFile))

        // Neither retry nor file replacement is allowed yet.
        viewModel.startUpload()
        viewModel.selectSampleFile()

        let callCount = await service.callCount
        #expect(callCount == 1)
        #expect(viewModel.state == .cancelling(selectedFile))

        // Simulate a service returning success despite cancellation.
        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()

        // Late success must not become a successful UI result.
        #expect(viewModel.state == .cancelled(selectedFile))

        // Cleanup now permits retry.
        viewModel.startUpload()
        await service.waitUntilStarted()

        let retryCallCount = await service.callCount
        let retryUploadIDs = await service.receivedUploadIDs

        #expect(retryCallCount == 2)
        #expect(retryUploadIDs == [uploadID, uploadID])

        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()

        guard case .succeeded(let file, let receipt) = viewModel.state else {
            Issue.record("Expected retry to succeed.")
            return
        }

        #expect(file == selectedFile)
        #expect(receipt.uploadID == uploadID)
    }
    
    @Test
    func failurePreservesFileAndAllowsRetry() async throws {
        let service = ControlledUploadService()
        let viewModel = UploadViewModel(service: service)

        viewModel.selectSampleFile()

        guard case .ready(let selectedFile) = viewModel.state else {
            Issue.record("Expected ready state.")
            return
        }

        viewModel.startUpload()
        await service.waitUntilStarted()

        let initialIDs = await service.receivedUploadIDs
        let uploadID = try #require(initialIDs.first)

        await service.fail()
        await viewModel.waitForCurrentUpload()

        guard case .failed(let file, let message) = viewModel.state else {
            Issue.record("Expected failed state.")
            return
        }

        #expect(file == selectedFile)
        #expect(!message.isEmpty)

        viewModel.startUpload()
        await service.waitUntilStarted()

        let retryIDs = await service.receivedUploadIDs
        #expect(retryIDs == [uploadID, uploadID])

        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()

        guard case .succeeded(let uploadedFile, let receipt) =
            viewModel.state else {
            Issue.record("Expected retry to succeed.")
            return
        }

        #expect(uploadedFile == selectedFile)
        #expect(receipt.uploadID == uploadID)
    }
    
    @Test
    func progressRejectsStaleAttemptsAndRegressions() async throws {
        let service = ControlledUploadService()
        let viewModel = UploadViewModel(service: service)

        viewModel.selectSampleFile()
        viewModel.startUpload()
        await service.waitUntilStarted()

        guard case .uploading(let file, let attemptID, _) =
            viewModel.state else {
            Issue.record("Expected uploading state.")
            return
        }

        viewModel.receiveProgress(0.6, attemptID: attemptID)

        #expect(viewModel.state == .uploading(
            file: file,
            attemptID: attemptID,
            progress: 0.6
        ))

        // Progress cannot move backwards.
        viewModel.receiveProgress(0.2, attemptID: attemptID)

        // A different attempt cannot update this upload.
        viewModel.receiveProgress(0.9, attemptID: UUID())

        // Non-finite values must be ignored.
        viewModel.receiveProgress(.nan, attemptID: attemptID)

        #expect(viewModel.state == .uploading(
            file: file,
            attemptID: attemptID,
            progress: 0.6
        ))

        // Values above 1 are clamped; 100% is not success.
        viewModel.receiveProgress(1.5, attemptID: attemptID)

        #expect(viewModel.state == .uploading(
            file: file,
            attemptID: attemptID,
            progress: 1
        ))

        viewModel.cancelUpload()

        // Even a matching attempt cannot update a cancelling screen.
        viewModel.receiveProgress(0.8, attemptID: attemptID)
        #expect(viewModel.state == .cancelling(file))

        let uploadIDs = await service.receivedUploadIDs
        let uploadID = try #require(uploadIDs.first)

        await service.succeed(uploadID: uploadID)
        await viewModel.waitForCurrentUpload()

        #expect(viewModel.state == .cancelled(file))
    }
}
