//
//  AppleAuthManager.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Manages Sign in with Apple state, credential validation, Keychain storage, and Sign Out.
//

import Foundation
import SwiftUI
import AuthenticationServices

class AppleAuthManager: ObservableObject {
    
    static let shared = AppleAuthManager()
    private let userIdentifierKey = "appleUserIdentifier"
    
    @Published var isAuthenticated: Bool = false
    @Published var userEmail: String? = nil
    @Published var userName: String? = nil
    
    private init() {
        checkCredentialState()
    }
    
    func checkCredentialState() {
        if let storedUserId = KeychainHelper.shared.read(forKey: userIdentifierKey), !storedUserId.isEmpty {
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            appleIDProvider.getCredentialState(forUserID: storedUserId) { [weak self] state, _ in
                DispatchQueue.main.async {
                    switch state {
                    case .authorized:
                        self?.isAuthenticated = true
                    case .revoked, .notFound:
                        self?.signOut()
                    default:
                        // Allow fallback if state check fails temporarily
                        self?.isAuthenticated = true
                    }
                }
            }
        } else {
            self.isAuthenticated = false
        }
    }
    
    func handleSuccessfulAuth(userIdentifier: String, email: String?, fullName: PersonNameComponents?) {
        KeychainHelper.shared.save(userIdentifier, forKey: userIdentifierKey)
        if let email = email {
            UserDefaults.standard.set(email, forKey: "appleUserEmail")
        }
        if let givenName = fullName?.givenName {
            UserDefaults.standard.set(givenName, forKey: "appleUserName")
        }
        
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.userEmail = email ?? UserDefaults.standard.string(forKey: "appleUserEmail")
            self.userName = fullName?.givenName ?? UserDefaults.standard.string(forKey: "appleUserName")
        }
    }
    
    func signOut() {
        KeychainHelper.shared.delete(forKey: userIdentifierKey)
        DispatchQueue.main.async {
            self.isAuthenticated = false
        }
    }
}
