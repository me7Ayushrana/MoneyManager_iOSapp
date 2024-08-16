//
//  GeminiKeySetupSheet.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Modal sheet providing instructions, direct Google AI Studio access link, API key entry, validation, and Keychain persistence.
//

import SwiftUI

struct GeminiKeySetupSheet: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var apiKeyInput: String = ""
    @State private var isSecured: Bool = true
    @State private var isValidating: Bool = false
    @State private var validationStatus: ValidationStatus = .idle
    @State private var errorMessage: String = ""
    
    enum ValidationStatus {
        case idle
        case success
        case failure
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Toolbar
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gemini AI Setup ✨")
                                .modifier(InterFont(.bold, size: 20))
                                .foregroundColor(Color.text_primary_color)
                            Text("Unlock MintAI Financial Assistant")
                                .modifier(InterFont(.regular, size: 12))
                                .foregroundColor(Color.text_secondary_color)
                        }
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color.text_secondary_color)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // Overview Banner
                            HStack(spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        LinearGradient(gradient: Gradient(colors: [Color.main_color, Color.main_color.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free & Unlimited AI")
                                        .modifier(InterFont(.bold, size: 15))
                                        .foregroundColor(Color.text_primary_color)
                                    Text("Use your free Google Gemini API key to ask questions about your expenses and get smart budget tips.")
                                        .modifier(InterFont(.regular, size: 12))
                                        .foregroundColor(Color.text_secondary_color)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .background(Color.secondary_color)
                            .cornerRadius(16)
                            
                            // Step 1: Create Key
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("STEP 1")
                                        .modifier(InterFont(.bold, size: 11))
                                        .foregroundColor(Color.main_color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.main_color.opacity(0.12))
                                        .cornerRadius(6)
                                    Text("Get a Free Gemini API Key")
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(Color.text_primary_color)
                                }
                                
                                Text("Tap below to open Google AI Studio in Safari, sign in with your Google Account, and click 'Create API Key'.")
                                    .modifier(InterFont(.regular, size: 12))
                                    .foregroundColor(Color.text_secondary_color)
                                
                                Button(action: openGoogleAIStudio) {
                                    HStack {
                                        Image(systemName: "safari.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Open Google AI Studio")
                                            .modifier(InterFont(.semiBold, size: 14))
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(Color.main_color)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.main_color.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(16)
                            .background(Color.secondary_color)
                            .cornerRadius(16)
                            
                            // Step 2: Paste & Validate Key
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("STEP 2")
                                        .modifier(InterFont(.bold, size: 11))
                                        .foregroundColor(Color.main_color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.main_color.opacity(0.12))
                                        .cornerRadius(6)
                                    Text("Paste Your API Key")
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(Color.text_primary_color)
                                }
                                
                                HStack {
                                    if isSecured {
                                        SecureField("AIzaSy...", text: $apiKeyInput)
                                            .modifier(InterFont(.regular, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                    } else {
                                        TextField("AIzaSy...", text: $apiKeyInput)
                                            .modifier(InterFont(.regular, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                    }
                                    
                                    Button(action: { isSecured.toggle() }) {
                                        Image(systemName: isSecured ? "eye.slash" : "eye")
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                }
                                .padding(14)
                                .background(Color.primary_color)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.main_color.opacity(0.3), lineWidth: 1)
                                )
                                
                                // Status Feedback
                                if validationStatus == .success {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Key Validated & Saved Successfully!")
                                            .modifier(InterFont(.medium, size: 12))
                                            .foregroundColor(.green)
                                    }
                                } else if validationStatus == .failure {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(errorMessage)
                                            .modifier(InterFont(.medium, size: 12))
                                            .foregroundColor(.red)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                
                                // Action Buttons
                                Button(action: validateAndSaveKey) {
                                    HStack {
                                        if isValidating {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.trailing, 6)
                                        } else {
                                            Image(systemName: "checkmark.seal.fill")
                                        }
                                        Text(isValidating ? "Validating Key..." : "Validate & Save Key")
                                            .modifier(InterFont(.bold, size: 15))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color.main_color)
                                    .cornerRadius(12)
                                }
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                                
                                if GeminiAIService.shared.isKeyConfigured {
                                    Button(action: removeKey) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Remove Stored Key")
                                                .modifier(InterFont(.medium, size: 13))
                                        }
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.secondary_color)
                            .cornerRadius(16)
                            
                            Spacer().frame(height: 30)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if let existingKey = GeminiAIService.shared.apiKey {
                self.apiKeyInput = existingKey
                self.validationStatus = .success
            }
        }
    }
    
    private func openGoogleAIStudio() {
        if let url = URL(string: "https://aistudio.google.com/app/apikey") {
            UIApplication.shared.open(url)
        }
    }
    
    private func validateAndSaveKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        self.isValidating = true
        self.validationStatus = .idle
        self.errorMessage = ""
        
        GeminiAIService.shared.validateApiKey(trimmedKey) { result in
            self.isValidating = false
            switch result {
            case .success:
                GeminiAIService.shared.apiKey = trimmedKey
                self.validationStatus = .success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.presentationMode.wrappedValue.dismiss()
                }
            case .failure(let err):
                self.validationStatus = .failure
                self.errorMessage = err.localizedDescription
            }
        }
    }
    
    private func removeKey() {
        GeminiAIService.shared.apiKey = nil
        self.apiKeyInput = ""
        self.validationStatus = .idle
    }
}
