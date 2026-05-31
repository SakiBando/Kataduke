//
//  CleaningView.swift
//  Kataduke
//
//  Created by Saki on 2025/12/21.
//

import SwiftUI

struct CleaningView: View{
    
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    var onFinishFlow: () -> Void
    @State private var timer: Timer!
    @State private var secondsElapsed: Double = 0.0
    @State private var isRunning = false
    @State private var isShowAlert = false
    @State private var isShowResult = false
    
    
    var body: some View {
        
        NavigationStack {
            VStack {
                Text(String(format: "%.2f",secondsElapsed)).font(.title)
                HStack {
                    if isRunning {
                        Button{
                            pause()
                        } label: {
                            Image(systemName: "pause.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.orange)
                                .clipShape(.circle)
                            
                        }
                        
                    }else{
                        Button{
                            start()
                        } label: {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.green)
                                .clipShape(.circle)
                        }
                    }
                    if secondsElapsed != 0.0{
                        Button{
                            stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.red)
                                .clipShape(.circle)
                        }
                    }
                    
                }
                Button("仮保存") {
                    isShowAlert.toggle()
                }
                .alert("仮保存しますか", isPresented: $isShowAlert) {
                    Button("戻る"){}
                    Button("仮保存する"){pause()}
                }
                Button("完了") {
                    stop()
                    isShowResult = true
                }
            }
            
            //.navigationDestination(isPresented: $isShowResult){
            //PhotoafterView()
            .navigationDestination(isPresented: $isShowResult) {
                PhotoafterView(
                    secondsElapsed: secondsElapsed,
                    beforeImage: $beforeImage,
                    afterImage: $afterImage,
                    onFinishFlow: onFinishFlow
                )
            }

            
            }
            .onAppear {
                print("[CleaningView] onAppear. before image exists: \(beforeImage != nil)")
            }
            
        }
    
    //                NavigationLink("", isActive: $isShowResult) {
    //                    ResultView()
    //                }
    
    func start() {
        print("[CleaningView] start timer")
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {_ in secondsElapsed += 0.1}
        isRunning = true
    }
    
    func pause() {
        print("[CleaningView] pause timer at \(secondsElapsed)")
        timer.invalidate()
        isRunning = false
    }
    
    func stop() {
        print("[CleaningView] stop timer at \(secondsElapsed)")
        timer.invalidate()
        isRunning = false
        let saveTime: Double
        saveTime = secondsElapsed
        UserDefaults.standard.set(saveTime, forKey: "saki-chan")
        
        secondsElapsed = 0.0
    }
}

#Preview {
    CleaningView(beforeImage: .constant(nil), afterImage: .constant(nil), onFinishFlow: {})
}
