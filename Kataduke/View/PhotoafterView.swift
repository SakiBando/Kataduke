//
//  PhotoafterView.swift
//  Kataduke
//
//  Created by Saki on 2026/01/12.
//
import SwiftUI

struct PhotoafterView: View {
    let secondsElapsed: Double
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    let playedTracks: [PlayedTrackInfo]
    var onFinishFlow: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var showResultView = false
    
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear {
                showCamera = true
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: handleCameraDismiss) {
                AfterCameraPicker(image: $afterImage)
            }
            .fullScreenCover(isPresented: $showResultView) {
                ResultView(
                    resultTimer: secondsElapsed,
                    beforeImage: $beforeImage,
                    afterImage: $afterImage,
                    playedTracks: playedTracks,
                    onFinishFlow: onFinishFlow
                )
            }
    }
    
    private func handleCameraDismiss() {
        guard afterImage != nil else {
            dismiss()
            return
        }
        
        showResultView = true
    }
}

private struct AfterCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: AfterCameraPicker
        
        init(_ parent: AfterCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.editedImage] as? UIImage {
                parent.image = uiImage
            } else if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PhotoafterView(
        secondsElapsed: 0,
        beforeImage: .constant(nil),
        afterImage: .constant(nil),
        playedTracks: [],
        onFinishFlow: {}
    )
}
