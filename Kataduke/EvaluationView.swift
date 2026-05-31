//
//  EvaluationView.swift
//  Kataduke
//
//  Created by Saki on 2026/05/17.
//

import SwiftUI
import GoogleGenerativeAI

struct EvaluationView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .onAppear() {
                print("[DEBUG]onappar")
                Task {
                    print("[DEBUG]task")
                    await runGemini()
                }
            }
    }
    func runGemini() async {
        print("[DEBUG]runGemini")
        // モデルの準備
        let model = GenerativeModel(
            name: "models/gemini-pro",
            apiKey: APIKey.default
        )
        
        // 推論の実行
        do {
            let response = try await model.generateContent("photobeforeの写真とphotoafterの写真を比較して綺麗さと時間を考慮して、どのくらい綺麗になったかを散らかっているが0%、綺麗が100%としてパーセンテージで表してください")
            if let text = response.text {
                print("[DEBUG]", text)
            }
        } catch {
            print("Error: \(error)")
        }
    }
}

#Preview {
    EvaluationView()
}

