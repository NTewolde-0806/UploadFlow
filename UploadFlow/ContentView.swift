import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = UploadViewModel(
        service: SimulatedUploadService()
    )

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Fictional files and simulated uploads only.")
                        .foregroundStyle(.secondary)
                }

                Section("Upload") {
                    switch viewModel.state {
                    case .idle:
                        Text("No file selected.")

                    case .ready(let file):
                        fileDetails(file)
                        Button("Start Upload") {
                            viewModel.startUpload()
                        }

                    case .uploading(let file, _, let progress):
                        fileDetails(file)

                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()

                        Button("Cancel Upload", role: .destructive) {
                            viewModel.cancelUpload()
                        }

                    case .cancelling(let file):
                        fileDetails(file)
                        ProgressView("Cancelling…")

                        Text("Wait for this attempt to finish before retrying.")
                            .foregroundStyle(.secondary)

                    case .cancelled(let file):
                        fileDetails(file)
                        Text("Upload cancelled locally.")

                        Button("Retry Upload") {
                            viewModel.startUpload()
                        }

                    case .failed(let file, let message):
                        fileDetails(file)

                        Text(message)
                            .foregroundStyle(.red)

                        Button("Retry Upload") {
                            viewModel.startUpload()
                        }

                    case .succeeded(let file, let receipt):
                        fileDetails(file)

                        Label(
                            "Simulated upload complete",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)

                        LabeledContent(
                            "Receipt",
                            value: receipt.id.uuidString
                        )
                        .font(.caption)
                    }
                }

                Section {
                    Button("Select Fictional File") {
                        viewModel.selectSampleFile()
                    }
                    .disabled(isBusy)
                }
            }
            .navigationTitle("UploadFlow")
            .onDisappear {
                viewModel.cancelUpload()
            }
        }
    }

    private var isBusy: Bool {
        switch viewModel.state {
        case .uploading, .cancelling:
            return true
        default:
            return false
        }
    }

    private func fileDetails(_ file: UploadFile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(file.name)
                .font(.headline)

            Text("\(file.sizeInBytes) bytes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
