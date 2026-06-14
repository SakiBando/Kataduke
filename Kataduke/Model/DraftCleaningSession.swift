//
//  DraftCleaningSession.swift
//  Kataduke
//
//  Created by Saki on 2026/06/13.
//

import Foundation
import SwiftData

@Model
final class DraftCleaningSession {
    var createdAt: Date
    var updatedAt: Date
    var elapsedTime: Double
    var songIDRawValue: String
    var songTitle: String
    var songArtistName: String
    var beforeImageData: Data?
    
    init(
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        elapsedTime: Double,
        songIDRawValue: String,
        songTitle: String,
        songArtistName: String,
        beforeImageData: Data?
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.elapsedTime = elapsedTime
        self.songIDRawValue = songIDRawValue
        self.songTitle = songTitle
        self.songArtistName = songArtistName
        self.beforeImageData = beforeImageData
    }
}
