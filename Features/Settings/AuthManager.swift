import CryptoKit
import AuthenticationServices
import Supabase
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var currentNonce: String?

    private init() {
        Task { await checkSession() }
    }
    
    func checkSession() async {
        do {
            let session = try await AppEnvironment.shared.supabase.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
        } catch {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    func signOut() async {
        do {
            try await AppEnvironment.shared.supabase.auth.signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        } catch {
            AppLogger.error("AuthManager: Chyba při odhlášení: \(error)")
        }
    }
    
    // MARK: - Apple Sign In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Nelze generovat náhodná čísla.")
                }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
    
    func startAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        
        return request
    }
    
    func handleAppleSignInResult(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    errorMessage = "Chyba zabezpečení: Neplatný nonce."
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    errorMessage = "Nepodařilo se získat identity token od Apple."
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = "Chyba formátu tokenu."
                    return
                }
                
                do {
                    // Supabase přihlášení pomocí ID Tokenu
                    // (Aktualizováno pro Supabase-Swift v2)
                    let authResponse = try await AppEnvironment.shared.supabase.auth.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                    )
                    self.currentUser = authResponse.user
                    self.isAuthenticated = true
                    
                    // TODO: Vytvořit/aktualizovat UserProfile v naší DB s uživatelským jménem
                    
                } catch {
                    AppLogger.error("Chyba při přihlášení přes backend Supabase: \(error.localizedDescription)")
                    errorMessage = "Chyba při navázání spojení s databází."
                }
            }
        case .failure(let error):
            AppLogger.error("Apple Sign-In selhal: \(error.localizedDescription)")
            if let error = error as? ASAuthorizationError, error.code == .canceled {
                // Zrušeno uživatelem
            } else {
                errorMessage = "Přihlášení přes Apple se nezdařilo."
            }
        }
    }
}
