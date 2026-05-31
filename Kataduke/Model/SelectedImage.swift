//
//  SelectedImage.swift
//  Kataduke
//
//  Created by Saki on 2026/02/01.
//
import SwiftData
import UIKit

@Model
final class SelectedImage {
    var createdAt: Date
    var elapsedTime: Double
    var beforeImageData: Data?
    var afterImageData: Data?
    var beforeTidinessScore: Int?
    var afterTidinessScore: Int?
    var improvementScore: Int?
    
    init(
        createdAt: Date = Date(),
        elapsedTime: Double,
        beforeImageData: Data?,
        afterImageData: Data?,
        beforeTidinessScore: Int? = nil,
        afterTidinessScore: Int? = nil,
        improvementScore: Int? = nil
    ) {
        self.createdAt = createdAt
        self.elapsedTime = elapsedTime
        self.beforeImageData = beforeImageData
        self.afterImageData = afterImageData
        self.beforeTidinessScore = beforeTidinessScore
        self.afterTidinessScore = afterTidinessScore
        self.improvementScore = improvementScore
    }
}

