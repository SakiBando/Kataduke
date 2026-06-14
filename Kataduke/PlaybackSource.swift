//
//  PlaybackSource.swift
//  Kataduke
//
//  Created by Saki on 2026/06/14.
//

import Foundation
import MediaPlayer
import MusicKit

enum PlaybackSource {
    case appleMusic([Track])
    case local([MPMediaItem])
}
