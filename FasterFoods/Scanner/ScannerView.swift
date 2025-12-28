import AVFoundation
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                ScannerViewControllerRepresentable(
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

private struct ScannerViewControllerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

private final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate
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
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupSession()
                    } else {
                        self.onError?("Camera access is required to scan.")
                    }
                }
            }
        case .denied, .restricted:
            onError?("Camera access is required to scan.")
        @unknown default:
            onError?("Camera access is required to scan.")
        }
    }

    private func setupSession() {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?("Camera not available.")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            onError?("Could not access camera.")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            onError?("Could not start camera.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8, .ean13, .upce, .code39, .code93, .code128, .qr,
            ]
        } else {
            onError?("Could not start camera.")
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
        isConfigured = true
        session.startRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan else { return }
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        guard let value = object.stringValue, !value.isEmpty else { return }
        didScan = true
        Task { [weak self] in
            guard let self else { return }
            let resolvedName =
                await OpenFoodFactsClient.shared
                .productName(for: value) ?? value
            await MainActor.run {
                self.onScan?(resolvedName)
            }
        }
    }
}

private final class OpenFoodFactsClient {
    static let shared = OpenFoodFactsClient()
    private init() {}

    func productName(for code: String) async -> String? {
        guard
            let url = URL(
                string: "https://world.openfoodfacts.net/api/v2/product/\(code)"
            )
        else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
            else {
                return nil
            }
            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            let name = decoded.product?.productNameEnglish?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return name?.isEmpty == false ? name : nil
        } catch {
            return nil
        }
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsProduct: Decodable {
    let productNameEnglish: String?

    private enum CodingKeys: String, CodingKey {
        case productNameEnglish = "product_name_en"
    }
}
