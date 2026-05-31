//
//  ResultItem.swift
//  Kataduke
//
//  Created by Saki on 2026/02/01.
//

import SwiftData

@Model
final class ResultItem {
    var title: String
    var content: String
    var isDone: Bool
    init(title: String, content: String, isDone: Bool) {
        self.title = title
        self.content = content
        self.isDone = isDone
    }
}
