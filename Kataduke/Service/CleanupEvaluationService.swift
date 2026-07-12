//
//  GenemiFile.swift
//  Kataduke
//
//  Created by Saki on 2026/05/31.
//

//import Foundation
import UIKit
import GoogleGenerativeAI

enum CleanupEvaluationService {
    private static let candidateModelNames = [
        "models/gemini-2.5-flash",
        "models/gemini-2.5-flash-lite"
    ]
    
    static func evaluate(before beforeImage: UIImage, after afterImage: UIImage, elapsedTime: Double) async throws -> CleanupEvaluation {
        let prompt = """
        あなたは部屋の片付け評価アシスタントです。
        1枚目が片付け前、2枚目が片付け後です。
        見えている範囲だけを根拠に、物の散乱、床や机の露出、分類の整い方、生活感のノイズ量を評価してください。
        時間は参考情報ですが、見た目の改善度を優先してください。
        必ずJSONのみを返してください。説明文やmarkdownは禁止です。
        
        {
          "beforeScore": 0-100の整数,
          "afterScore": 0-100の整数
        }
        
        経過時間(秒): \(Int(elapsedTime.rounded()))
        """
        
        let preparedBeforeImage = beforeImage.scaledForGemini()
        let preparedAfterImage = afterImage.scaledForGemini()
        
        var lastError: Error?
        for modelName in candidateModelNames {
            do {
                let model = GenerativeModel(name: modelName, apiKey: APIKey.default)
                let response = try await model.generateContent(prompt, preparedBeforeImage, preparedAfterImage)
                guard let text = response.text else {
                    throw CleanupEvaluationError.emptyResponse
                }
                return try parseEvaluation(from: text)
            } catch {
                print("[CleanupEvaluationService] \(modelName) failed: \(error)")
                lastError = error
            }
        }
        
        throw lastError ?? CleanupEvaluationError.emptyResponse
    }
    
    private static func parseEvaluation(from text: String) throws -> CleanupEvaluation {
        let jsonText = extractFirstJSONObject(from: text)
        guard let data = jsonText.data(using: .utf8) else {
            throw CleanupEvaluationError.invalidEncoding
        }
        
        do {
            return try JSONDecoder().decode(CleanupEvaluation.self, from: data)
        } catch {
            throw CleanupEvaluationError.invalidJSON(rawText: text)
        }
    }
    
    private static func extractFirstJSONObject(from text: String) -> String {
        guard
            let startIndex = text.firstIndex(of: "{"),
            let endIndex = text.lastIndex(of: "}")
        else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return String(text[startIndex...endIndex])
    }
}

enum CleanupEvaluationError: LocalizedError {
    case emptyResponse
    case invalidEncoding
    case invalidJSON(rawText: String)
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Geminiから評価結果を受け取れませんでした。"
        case .invalidEncoding:
            return "Geminiの評価結果を文字列として処理できませんでした。"
        case .invalidJSON(let rawText):
            return "Geminiの評価結果をJSONとして解析できませんでした: \(rawText)"
        }
    }
}

private extension UIImage {
    func scaledForGemini(maxDimension: CGFloat = 1024) -> UIImage {
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else {
            return self
        }
        
        let scaleRatio = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
