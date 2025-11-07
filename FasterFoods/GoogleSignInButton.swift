import SwiftUI
import GoogleSignIn

struct GoogleSignInButton: View {
    let onCompletion: (Result<GIDSignInResult, Error>) -> Void
    
    var body: some View {
        Button {
            handleSignIn()
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                    .font(.title3)
                Text("Sign in with Google")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func handleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            onCompletion(.failure(GoogleSignInError.noViewController))
            return
        }
        
        // Configuration is already set in FasterFoodsApp.init()
        // Verify it's configured
        guard GIDSignIn.sharedInstance.configuration != nil else {
            onCompletion(.failure(GoogleSignInError.noClientID))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                onCompletion(.failure(error))
                return
            }
            
            guard let result = result else {
                onCompletion(.failure(GoogleSignInError.noResult))
                return
            }
            
            onCompletion(.success(result))
        }
    }
}

struct GoogleSignInCoordinator {
    func handleSignInResult(_ result: GIDSignInResult) -> GoogleSignInCredentials? {
        let user = result.user
        
        guard let idToken = user.idToken?.tokenString else {
            return nil
        }
        
        let userID = user.userID ?? ""
        let email = user.profile?.email
        let firstName = user.profile?.givenName
        let lastName = user.profile?.familyName
        let profilePicURL = user.profile?.imageURL(withDimension: 200)?.absoluteString
        
        return GoogleSignInCredentials(
            userID: userID,
            idToken: idToken,
            email: email,
            firstName: firstName,
            lastName: lastName,
            profilePicURL: profilePicURL
        )
    }
}

struct GoogleSignInCredentials {
    let userID: String
    let idToken: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let profilePicURL: String?
}

enum GoogleSignInError: LocalizedError {
    case noViewController
    case noClientID
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Could not find a view controller to present sign in"
        case .noClientID:
            return "Google Client ID not configured"
        case .noResult:
            return "No sign in result returned"
        }
    }
}

