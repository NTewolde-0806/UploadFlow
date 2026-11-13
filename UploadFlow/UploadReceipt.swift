//
//  UploadReceipt.swift
//  UploadFlow
//
//  Created by Noh Tewolde on 11/13/26.
//

import Foundation

/// Confirmation returned after a simulated upload succeeds.
struct UploadReceipt: Equatable, Sendable {
    let id: UUID
    let uploadID: UUID
}
