import AVFoundation
import SwiftUI

struct FriendScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FriendScannerRepresentable(
                    onScan: { value in
                        onScan(value)
                        dismiss()
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
                .ignoresSafeArea()

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
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct FriendScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> FriendScannerViewController {
        let controller = FriendScannerViewController()
        controller.onScan = onScan
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: FriendScannerViewController, context: Context) {
    }
}

private final class FriendScannerViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate
{
    var onScan: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isConfigured && !session.isRunning {
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.onError?("Camera access is required to scan.")
                    }
                }
            }
        default:
            onError?("Camera access is required to scan.")
        }
    }

    private func setupSession() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?("Camera unavailable.")
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            onError?("Camera unavailable.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddInput(input), session.canAddOutput(metadataOutput) else {
            onError?("Camera unavailable.")
            return
        }

        session.addInput(input)
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        isConfigured = true
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let value = object.stringValue
        else {
            return
        }
        didScan = true
        onScan?(value)
    }
}
