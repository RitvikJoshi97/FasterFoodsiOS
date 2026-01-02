import AVFoundation
import SwiftUI

struct ScannedProductInfo: Equatable {
    let barcode: String
    let name: String
    let nutriments: ScannedNutriments?
    let productQuantity: Double?
    let productQuantityUnit: String?
    let servingQuantity: Double?
    let servingQuantityUnit: String?
}

struct ScannedNutriments: Decodable, Equatable {
    let proteins100g: Double?
    let fat100g: Double?
    let carbohydrates100g: Double?
    let energy100g: Double?
    let energyValue: Double?
    let energyUnit: String?

    private enum CodingKeys: String, CodingKey {
        case proteins100g = "proteins_100g"
        case fat100g = "fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case energy100g = "energy_100g"
        case energyValue = "energy_value"
        case energyUnit = "energy_unit"
    }
}

struct ScannerView: View {
    @EnvironmentObject private var toastService: ToastService
    @Environment(\.dismiss) private var dismiss
    let onScan: (ScannedProductInfo) -> Void
    @State private var errorMessage: String?
    @State private var isResolving = false
    @State private var missingProductCode: String?
    @State private var isLearnMorePresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScannerViewControllerRepresentable(
                    onScan: { value in
                        resolveProduct(for: value)
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
                .ignoresSafeArea()

                if isResolving {
                    ProgressView("Looking up product…")
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Product not found",
                isPresented: Binding(
                    get: { missingProductCode != nil },
                    set: { if !$0 { missingProductCode = nil } }
                )
            ) {
                Button("Add") {
                    toastService.show("Added")
                    dismiss()
                }
                Button("Learn More") {
                    isLearnMorePresented = true
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(
                    "We weren't able to find this product in our database, sorry. We'll add this if you wouldn't mind."
                )
            }
            .sheet(isPresented: $isLearnMorePresented) {
                LearnMoreSheet()
            }
        }
    }

    private func resolveProduct(for code: String) {
        guard !isResolving else { return }
        isResolving = true
        Task {
            do {
                let result = try await OpenFoodFactsClient.shared.lookupProduct(for: code)
                await MainActor.run {
                    isResolving = false
                    switch result {
                    case .found(let product):
                        onScan(product)
                        dismiss()
                    case .notFound:
                        missingProductCode = code
                    }
                }
            } catch {
                await MainActor.run {
                    isResolving = false
                    errorMessage = "We couldn't look up that product. Please try again."
                }
            }
        }
    }
}

private struct LearnMoreSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How this helps")
                        .font(.headline)
                    Text(
                        "We contribute to Open Food Facts. If you add a product, we use your photo and its barcode to help identify it."
                    )
                    Text(
                        "Open Food Facts powers many other projects by keeping food data open and reusable for everyone."
                    )
                }
                .padding(20)
            }
            .navigationTitle("Learn more")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
        onScan?(value)
    }
}

private final class OpenFoodFactsClient {
    static let shared = OpenFoodFactsClient()
    private init() {}

    enum LookupResult {
        case found(ScannedProductInfo)
        case notFound
    }

    func lookupProduct(for code: String) async throws -> LookupResult {
        guard
            let url = URL(
                string:
                    "https://world.openfoodfacts.net/api/v2/product/\(code)?fields=product_name,nutriments,product_quantity,product_quantity_unit,serving_quantity,serving_quantity_unit"
            )
        else {
            return .notFound
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 404 {
            return .notFound
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        guard decoded.status == 1 else {
            return .notFound
        }

        guard let product = decoded.product else {
            return .notFound
        }

        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolvedName = name, !resolvedName.isEmpty else {
            return .notFound
        }

        let info = ScannedProductInfo(
            barcode: code,
            name: resolvedName,
            nutriments: product.nutriments,
            productQuantity: product.productQuantity.flatMap(parseDouble),
            productQuantityUnit: product.productQuantityUnit,
            servingQuantity: product.servingQuantity.flatMap(parseDouble),
            servingQuantityUnit: product.servingQuantityUnit
        )
        return .found(info)
    }

    private func parseDouble(_ value: String) -> Double? {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let filtered = value.unicodeScalars.filter { allowedCharacters.contains($0) }
        return Double(String(filtered))
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let status: Int?
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let nutriments: ScannedNutriments?
    let productQuantity: String?
    let productQuantityUnit: String?
    let servingQuantity: String?
    let servingQuantityUnit: String?

    private enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case nutriments
        case productQuantity = "product_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case servingQuantity = "serving_quantity"
        case servingQuantityUnit = "serving_quantity_unit"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        nutriments = try container.decodeIfPresent(ScannedNutriments.self, forKey: .nutriments)
        productQuantity = Self.decodeFlexibleString(container, key: .productQuantity)
        productQuantityUnit = try container.decodeIfPresent(
            String.self, forKey: .productQuantityUnit)
        servingQuantity = Self.decodeFlexibleString(container, key: .servingQuantity)
        servingQuantityUnit = try container.decodeIfPresent(
            String.self, forKey: .servingQuantityUnit)
    }

    private static func decodeFlexibleString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let value = try? container.decode(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? container.decode(Int.self, forKey: key) {
            return String(value)
        }
        return nil
    }
}
