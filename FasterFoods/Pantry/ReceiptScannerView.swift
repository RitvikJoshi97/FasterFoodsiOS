import SwiftUI
import UIKit
import Vision
import VisionKit

struct ReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (ReceiptScanResult) -> Void
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if #available(iOS 13.0, *), VNDocumentCameraViewController.isSupported {
                    ReceiptDocumentCameraRepresentable(
                        onCapture: { image in
                            recognizeText(from: image) { text in
                                print("Receipt OCR:\n\(text)")
                                guard let result = ReceiptScanResult.mockResult() else {
                                    errorMessage = "Couldn't read receipt data."
                                    return
                                }
                                print("Receipt JSON:\n\(ReceiptScanResult.mockJSON)")
                                onCapture(result)
                                dismiss()
                            }
                        },
                        onError: { message in
                            errorMessage = message
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)
                        Text("Document scanning not supported")
                            .font(.headline)
                        Text("This device doesn't support the document scanner.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.primary)
                    .padding(20)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private struct ReceiptDocumentCameraRepresentable: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onError: onError, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(
            onCapture: @escaping (UIImage) -> Void,
            onError: @escaping (String) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onError = onError
            self.onCancel = onCancel
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onError(error.localizedDescription)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                onError("No pages captured.")
                return
            }
            let image = scan.imageOfPage(at: 0)
            onCapture(image)
        }
    }
}

extension ReceiptScannerView {
    fileprivate func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                print("Receipt OCR error: \(error.localizedDescription)")
            }
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let text =
                observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            DispatchQueue.main.async {
                completion(text)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Receipt OCR error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion("")
                }
            }
        }
    }
}
