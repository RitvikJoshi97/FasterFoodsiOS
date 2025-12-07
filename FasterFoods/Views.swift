import AuthenticationServices
import GoogleSignIn
import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isResending = false
    @State private var isAppleSignInLoading = false
    @State private var isGoogleSignInLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var needsVerification = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let logo = UIImage(named: colorScheme == .dark ? "dark_icon" : "light_icon") {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.bottom, 8)
                }

                Text("FasterFoods")
                    .font(.largeTitle)
                    .bold()

                AppleSignInButton { result in
                    Task { await handleAppleSignIn(result) }
                }
                .disabled(isAppleSignInLoading)
                .overlay {
                    if isAppleSignInLoading {
                        ProgressView()
                    }
                }

                GoogleSignInButton { result in
                    Task { await handleGoogleSignIn(result) }
                }
                .disabled(isGoogleSignInLoading)
                .overlay {
                    if isGoogleSignInLoading {
                        ProgressView()
                    }
                }

                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    Text("or")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(.vertical, 8)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                if let msg = errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                if let info = infoMessage {
                    Text(info)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await handleLogin() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text("Login")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(isFormValid ? 1 : 0.4))
                    .foregroundColor(.white.opacity(isFormValid ? 1 : 0.7))
                    .cornerRadius(8)
                }
                .disabled(!isFormValid || isLoading)

                if needsVerification {
                    VStack(spacing: 8) {
                        Text("Please verify your email before logging in.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await resendVerification() }
                        } label: {
                            HStack {
                                if isResending { ProgressView() }
                                Text("Resend verification email")
                            }
                        }
                        .disabled(isResending)
                    }
                }

                Divider()
                NavigationLink("Forgot password?") {
                    ForgotPasswordView(email: email)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding()
        }
        .glassNavigationBarStyle()
    }

    @MainActor
    private func handleLogin() async {
        isLoading = true
        needsVerification = false
        infoMessage = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await app.login(email: email, password: password)
        } catch let apiError as APIError {
            errorMessage = apiError.message
            needsVerification = apiError.unverified
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func resendVerification() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isResending = true
        infoMessage = nil
        errorMessage = nil
        defer { isResending = false }
        do {
            try await app.resendVerification(email: email)
            infoMessage = "Verification email sent to \(email)."
        } catch let apiError as APIError {
            errorMessage = apiError.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isAppleSignInLoading = true
        needsVerification = false
        infoMessage = nil
        errorMessage = nil
        defer { isAppleSignInLoading = false }

        do {
            let authorization = try result.get()
            let coordinator = AppleSignInCoordinator()

            guard let credentials = coordinator.handleAuthorization(authorization) else {
                errorMessage = "Failed to process Apple Sign In credentials"
                return
            }

            try await app.loginWithApple(
                identityToken: credentials.identityToken,
                userIdentifier: credentials.userIdentifier,
                email: credentials.email,
                firstName: credentials.firstName,
                lastName: credentials.lastName,
                authorizationCode: credentials.authorizationCode
            )
        } catch let apiError as APIError {
            errorMessage = apiError.message
        } catch {
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleGoogleSignIn(_ result: Result<GIDSignInResult, Error>) async {
        isGoogleSignInLoading = true
        needsVerification = false
        infoMessage = nil
        errorMessage = nil
        defer { isGoogleSignInLoading = false }

        do {
            let signInResult = try result.get()
            let coordinator = GoogleSignInCoordinator()

            guard let credentials = coordinator.handleSignInResult(signInResult) else {
                errorMessage = "Failed to process Google Sign In credentials"
                return
            }

            try await app.loginWithGoogle(
                idToken: credentials.idToken,
                userID: credentials.userID,
                email: credentials.email,
                firstName: credentials.firstName,
                lastName: credentials.lastName
            )
        } catch let apiError as APIError {
            errorMessage = apiError.message
        } catch {
            errorMessage = "Google Sign In failed: \(error.localizedDescription)"
        }
    }
}

struct HomeView: View {
    var body: some View {
        RootTabShell()
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var message: String?
    @State private var isError = false
    @State private var isSubmitting = false

    init(email: String = "") {
        _email = State(initialValue: email)
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section(header: Text("Account email")) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            if let message {
                Text(message)
                    .foregroundColor(isError ? .red : .green)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isSubmitting { ProgressView() }
                    Text("Send reset email")
                }
            }
            .disabled(!isFormValid || isSubmitting)

            if !isSubmitting, message != nil, !isError {
                Button("Back to login") { dismiss() }
            }
        }
        .navigationTitle("Reset Password")
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        message = nil
        isError = false
        defer { isSubmitting = false }
        do {
            try await app.forgotPassword(email: email)
            message =
                "If an account exists for \(email), you'll receive reset instructions shortly."
        } catch let apiError as APIError {
            message = apiError.message
            isError = true
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}

struct SplashView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8

    var body: some View {
        ZStack {
            // Green gradient that adapts to light/dark mode
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark
                        ? [
                            // Dark mode: Forest green to almost black-green
                            Color(hex: "#1B5E20"),  // Forest green
                            Color(hex: "#0A2E12"),  // Almost black-green
                        ]
                        : [
                            // Light mode: Vibrant green
                            Color(hex: "#2E7D32"),  // Top green
                            Color(hex: "#0f4c1a"),  // Bottom darker green
                        ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                if let logo = UIImage(named: colorScheme == .dark ? "dark_icon" : "light_icon") {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
                Text("FasterFoods")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            .padding()
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            // Ease in animation
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
                scale = 1.0
            }
        }
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RecommendationDetailSheet: View {
    let recommendation: ShoppingRecommendation
    let isUsing: Bool
    let isDismissing: Bool
    let onUse: () -> Void
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(recommendation.title)
                    .font(.title3.bold())
                if !recommendation.description.isEmpty {
                    ScrollView {
                        Text(recommendation.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }

                Spacer(minLength: 8)

                VStack(spacing: 12) {
                    Button(action: onUse) {
                        if isUsing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Use suggestion", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUsing)

                    Button(action: onDismiss) {
                        if isDismissing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Dismiss", systemImage: "hand.thumbsdown")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .disabled(isDismissing)
                }
            }
            .padding()
            .navigationTitle("Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct ChipFlow: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(
                ProposedViewSize(width: maxWidth, height: proposal.height))
            if maxWidth.isFinite,
                lineWidth > 0,
                lineWidth + subviewSize.width > maxWidth
            {
                totalHeight += lineHeight + verticalSpacing
                lineWidth = 0
                lineHeight = 0
            }
            if lineWidth > 0 {
                lineWidth += horizontalSpacing
            }
            lineWidth += subviewSize.width
            lineHeight = max(lineHeight, subviewSize.height)
        }

        totalHeight += lineHeight

        let finalWidth = maxWidth.isFinite ? maxWidth : lineWidth
        return CGSize(width: finalWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let maxWidth = bounds.width == 0 ? .infinity : bounds.width
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(
                ProposedViewSize(width: maxWidth, height: proposal.height))
            if maxWidth.isFinite,
                currentX > bounds.minX,
                currentX + subviewSize.width > bounds.maxX
            {
                currentX = bounds.minX
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: subviewSize.width, height: subviewSize.height)
            )

            currentX += subviewSize.width + horizontalSpacing
            lineHeight = max(lineHeight, subviewSize.height)
        }
    }
}

extension View {
    @ViewBuilder
    func interactiveKeyboardDismiss() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }

    @ViewBuilder
    func withDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.fraction(0.35), .medium])
        } else {
            self
        }
    }
}
