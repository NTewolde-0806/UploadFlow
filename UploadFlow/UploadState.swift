//
//  UploadState.swift
//  UploadFlow
//
//  Created by Noh Tewolde on 11/13/26.
//

import Foundation

enum UploadState: Equatable, Sendable {
    case idle
    case ready(UploadFile)

    case uploading(
        file: UploadFile,
        attemptID: UUID,
        progress: Double
    )

    case cancelling(UploadFile)
    case cancelled(UploadFile)

    case failed(
        file: UploadFile,
        message: String
    )

    case succeeded(
        file: UploadFile,
        receipt: UploadReceipt
    )
}
