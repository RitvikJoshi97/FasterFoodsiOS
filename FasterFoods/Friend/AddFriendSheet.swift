import CoreImage.CIFilterBuiltins
import SwiftUI

struct AddFriendSheet: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case share = "Share"
        case join = "Join"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .share
    @State private var inviteCode = AddFriendSheet.generateInviteCode()
    @State private var inviteExpiry = Date().addingTimeInterval(20 * 60)
    @State private var joinCode = ""
    @State private var isScannerPresented = false

    private var inviteLink: String {
        "https://fasterfoods.app/friends/invite?code=\(inviteCode)"
    }

    private var expiryText: String {
        "Valid for 20 minutes (until \(AddFriendSheet.timeFormatter.string(from: inviteExpiry)))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Add friend", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .share:
                    shareContent
                case .join:
                    joinContent
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                inviteCode = AddFriendSheet.generateInviteCode()
                inviteExpiry = Date().addingTimeInterval(20 * 60)
            }
            .sheet(isPresented: $isScannerPresented) {
                FriendScannerView { value in
                    applyScannedValue(value)
                }
            }
        }
    }

    private var shareContent: some View {
        VStack(spacing: 16) {
            QRCodeView(text: inviteLink)
                .frame(width: 200, height: 200)
            VStack(spacing: 6) {
                Text(inviteLink)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(inviteCode)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .tracking(3)
                Text(expiryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var joinContent: some View {
        VStack(spacing: 16) {
            Button {
                isScannerPresented = true
            } label: {
                Label("Scan", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            TextField("Enter 6 digit code", text: $joinCode)
                .keyboardType(.numberPad)
                .onChange(of: joinCode) { _, newValue in
                    joinCode = sanitizeCode(newValue)
                }
        }
    }

    private func sanitizeCode(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return String(digits.prefix(6))
    }

    private func applyScannedValue(_ value: String) {
        joinCode = sanitizeCode(value)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static func generateInviteCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }
}

private struct QRCodeView: View {
    private let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    init(text: String) {
        self.text = text
    }

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    Text("QR unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func makeImage() -> UIImage? {
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
