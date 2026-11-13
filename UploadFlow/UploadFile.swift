//
//  UploadFile.swift
//  UploadFlow
//
//  Created by Noh Tewolde on 11/13/26.
//

import Foundation

struct UploadFile: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let sizeInBytes: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        sizeInBytes: Int
    ) {
        self.id = id
        self.name = name
        self.sizeInBytes = sizeInBytes
    }
}
