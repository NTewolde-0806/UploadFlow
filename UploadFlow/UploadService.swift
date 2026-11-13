//
//  UploadService.swift
//  UploadFlow
//
//  Created by Noh Tewolde on 11/13/26.
//

import Foundation

nonisolated protocol UploadService: Sendable {
    func upload(
        _ file: UploadFile,
        uploadID: UUID,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> UploadReceipt
}
