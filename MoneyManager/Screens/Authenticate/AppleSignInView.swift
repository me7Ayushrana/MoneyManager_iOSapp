//
//  AppleSignInView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Clean, minimalist login screen with native SignInWithAppleButton.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var authManager = AppleAuthManager.shared
    
    var body: some View {
        ZStack {
            Color.primary_color.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Spacer()
                
                // TrackMint Branding
                VStack(spacing: 12) {
                    Image("pie_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                    
                    Text("TrackMint")
                        .modifier(InterFont(.bold, size: 28))
                        .foregroundColor(Color.text_primary_color)
                    
                    Text("Smart Expense Tracking & Cloud Sync")
                        .modifier(InterFont(.medium, size: 14))
                        .foregroundColor(Color.text_secondary_color)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    // Native Sign in with Apple Button
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                                    let userIdentifier = appleIDCredential.user
                                    let email = appleIDCredential.email
                                    let fullName = appleIDCredential.fullName
                                    
                                    authManager.handleSuccessfulAuth(
                                        userIdentifier: userIdentifier,
                                        email: email,
                                        fullName: fullName
                                    )
                                }
                            case .failure(let error):
                                print("⚠️ Sign in with Apple error: \(error.localizedDescription)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(themeManager.isDarkMode ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    
                    Text("Sign in to sync your expenses seamlessly across all your devices via iCloud.")
                        .modifier(InterFont(.regular, size: 12))
                        .foregroundColor(Color.text_secondary_color)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
