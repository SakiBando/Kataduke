//
//  CleanupEvaluation.swift
//  Kataduke
//
//  Created by Saki on 2026/06/13.
//

import Foundation

struct CleanupEvaluation: Decodable {
    let beforeScore: Int
    let afterScore: Int
    
    var clampedBeforeScore: Int {
        min(max(beforeScore, 0), 100)
    }
    
    var clampedAfterScore: Int {
        min(max(afterScore, 0), 100)
    }
    
    var improvementScore: Int {
        clampedAfterScore - clampedBeforeScore
    }
}
