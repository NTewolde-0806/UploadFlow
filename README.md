# UploadFlow

A standalone SwiftUI practice app demonstrating upload lifecycle
management with fictional file metadata and a simulated service.

## Scope

- Select a fictional file
- Display simulated upload progress
- Prevent duplicate upload starts
- Cancel an upload and wait for the active call to finish
- Retry after cancellation or failure
- Display a receipt after success

No real files are read, no network requests are made, and no
employer code or assets are used.

## Architecture

- UploadFile: immutable fictional file metadata
- UploadReceipt: simulated completion receipt
- UploadService: asynchronous service contract
- SimulatedUploadService: actor-based demonstration service
- UploadViewModel: MainActor-isolated state and task ownership
- ContentView: renders state and forwards user actions

## Identity

File identity describes the selected file.

The logical upload ID stays stable across retries. Each attempt
receives a new attempt ID to reject stale progress and cleanup.

Stable IDs alone do not provide server-side idempotency.
That would require an explicit backend contract.

## Cancellation

Cancel moves the screen to cancelling and requests task cancellation.
Retry and file replacement remain blocked until the call finishes.

Cancellation is cooperative. A returned result is checked for
cancellation before updating state. Local cancellation does not
guarantee that a remote server discarded an upload.

## Progress

Progress is constrained to 0...1 and cannot regress.
Non-finite values and mismatched attempt IDs are ignored.
Progress updates are accepted only while uploading.

Reaching 100% does not establish success; a receipt is required.

## Tests

Five deterministic tests cover:

1. Duplicate-start prevention
2. Successful completion and task cleanup
3. Cancellation, late success, and safe retry
4. Failure and retry with a stable logical upload ID
5. Progress filtering, clamping, and stale-attempt rejection

A controlled service uses continuations rather than timed sleeps.
Progress-handler tests invoke the handler directly; they do not
verify end-to-end callback delivery or real network behavior.

## Limitations

- In-memory state only
- No real file selection or upload
- No authentication, background transfer, or persistence
- No backend idempotency or remote cancellation guarantee
- Ordinary failure is exercised through tests, not the demo UI

## Running

Open UploadFlow.xcodeproj in Xcode and run the UploadFlow scheme.
Run the UploadFlowTests target to execute the tests.
