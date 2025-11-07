import SwiftUI
import AuthenticationServices

struct AppleSignInButton: View {
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: onCompletion
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
    }
}

struct AppleSignInCoordinator {
    func handleAuthorization(_ authorization: ASAuthorization) -> AppleSignInCredentials? {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return nil
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            return nil
        }
        
        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email
        let firstName = appleIDCredential.fullName?.givenName
        let lastName = appleIDCredential.fullName?.familyName
        
        return AppleSignInCredentials(
            userIdentifier: userIdentifier,
            identityToken: tokenString,
            email: email,
            firstName: firstName,
            lastName: lastName,
            authorizationCode: appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }
}

struct AppleSignInCredentials {
    let userIdentifier: String
    let identityToken: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let authorizationCode: String?
}

