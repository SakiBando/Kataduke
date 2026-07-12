////
////  PhotobeforeView.swift
////  Kataduke
////
////  Created by Saki on 2026/01/12.
////
import SwiftUI
import MusicKit
import MediaPlayer

struct PhotobeforeView: View {
    @Binding var beforeImage: UIImage?
    @Binding var afterImage: UIImage?
    let playbackSource: PlaybackSource
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCamera = false
    @State private var showCleaningView = false
    
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .onAppear {
                showCamera = true
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: handleCameraDismiss) {
                BeforeCameraPicker(image: $beforeImage)
            }
            .fullScreenCover(isPresented: $showCleaningView) {
                CleaningView(
                    beforeImage: $beforeImage,
                    afterImage: $afterImage,
                    playbackSource: playbackSource
                ) {
                    showCleaningView = false
                    dismiss()
                }
            }
            .toolbar(.hidden, for: .tabBar)
    }
    
    private func handleCameraDismiss() {
        guard beforeImage != nil else {
            dismiss()
            return
        }
        
        afterImage = nil
        showCleaningView = true
    }
}

private struct BeforeCameraPicker: UIViewControllerRepresentable {
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
        let parent: BeforeCameraPicker
        
        init(_ parent: BeforeCameraPicker) {
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
