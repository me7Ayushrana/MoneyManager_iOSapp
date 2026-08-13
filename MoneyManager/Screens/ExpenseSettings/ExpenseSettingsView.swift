//
//  ExpenseSettingsView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import AuthenticationServices

struct ExpenseSettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var authManager: AppleAuthManager
    
    @ObservedObject private var viewModel = ExpenseSettingsViewModel()
    @AppStorage(UD_MONTHLY_BUDGET) var monthlyBudget: Double = 5000.0
    
    @State private var selectDisplayCurrency = false
    @State private var showBudgetSheet = false
    @State private var selectedBudgetTag: String? = nil
    @State private var showSignOutAlert = false
    
    let tagOptions = [
        TRANS_TAG_TRANSPORT, TRANS_TAG_FOOD, TRANS_TAG_HOUSING,
        TRANS_TAG_INSURANCE, TRANS_TAG_MEDICAL, TRANS_TAG_SAVINGS,
        TRANS_TAG_PERSONAL, TRANS_TAG_ENTERTAINMENT, TRANS_TAG_UTILITIES, TRANS_TAG_OTHERS
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ToolbarModelView(title: "Settings") { self.presentationMode.wrappedValue.dismiss() }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            
                            // ── PREFERENCES SECTION ──
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PREFERENCES")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                // Biometric toggle
                                HStack {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(Color.main_color)
                                        .frame(width: 36, height: 36)
                                        .background(Color.main_color.opacity(0.12))
                                        .cornerRadius(10)
                                    TextView(text: "Enable \(viewModel.getBiometricType())", type: .button)
                                        .foregroundColor(Color.text_primary_color)
                                    Spacer()
                                    Toggle("", isOn: $viewModel.enableBiometric)
                                        .toggleStyle(SwitchToggleStyle(tint: Color.main_color))
                                }
                                .padding(14)
                                .background(Color.secondary_color)
                                .cornerRadius(12)
                                
                                // Display Currency selector
                                Button(action: { selectDisplayCurrency = true }) {
                                    HStack {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color.main_color)
                                            .frame(width: 36, height: 36)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(10)
                                        VStack(alignment: .leading, spacing: 2) {
                                            TextView(text: "Display Currency", type: .button)
                                                .foregroundColor(Color.text_primary_color)
                                            Text("Converts all totals to this currency")
                                                .modifier(InterFont(.regular, size: 11))
                                                .foregroundColor(Color.text_secondary_color)
                                        }
                                        Spacer()
                                        Text("\(symbolFor(currencyCode: viewModel.displayCurrency)) \(viewModel.displayCurrency)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.main_color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(8)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                    .padding(14)
                                    .background(Color.secondary_color)
                                    .cornerRadius(12)
                                }
                                .actionSheet(isPresented: $selectDisplayCurrency) {
                                    var buttons: [ActionSheet.Button] = SUPPORTED_CURRENCIES.map { curr in
                                        .default(Text(curr.displayLabel)) {
                                            viewModel.saveDisplayCurrency(code: curr.code, exchangeService: exchangeService)
                                        }
                                    }
                                    buttons.append(.cancel())
                                    return ActionSheet(title: Text("Display Currency"), message: Text("All summaries, totals, and charts will convert into this currency"), buttons: buttons)
                                }
                                
                                // Set Monthly Budget Row
                                Button(action: { showBudgetSheet = true }) {
                                    HStack {
                                        Image(systemName: "target")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color.main_color)
                                            .frame(width: 36, height: 36)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(10)
                                        VStack(alignment: .leading, spacing: 2) {
                                            TextView(text: "Set Monthly Budget", type: .button)
                                                .foregroundColor(Color.text_primary_color)
                                            Text("Used for budget progress & warnings")
                                                .modifier(InterFont(.regular, size: 11))
                                                .foregroundColor(Color.text_secondary_color)
                                        }
                                        Spacer()
                                        Text("\(symbolFor(currencyCode: viewModel.displayCurrency)) \(String(format: "%.0f", monthlyBudget.rounded()))")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.main_color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(8)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                    .padding(14)
                                    .background(Color.secondary_color)
                                    .cornerRadius(12)
                                }
                                .sheet(isPresented: $showBudgetSheet) {
                                    SetBudgetSheet(monthlyBudget: $monthlyBudget, displayCurrency: viewModel.displayCurrency) { _ in }
                                }
                            }
                            
                            // ── LIVE EXCHANGE RATES STATUS ──
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EXCHANGE RATES")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                HStack {
                                    Image(systemName: exchangeService.isUsingCachedRates ? "clock.arrow.circlepath" : "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(exchangeService.isUsingCachedRates ? Color(hex: "F59E0B") : Color.main_green)
                                        .frame(width: 36, height: 36)
                                        .background((exchangeService.isUsingCachedRates ? Color(hex: "F59E0B") : Color.main_green).opacity(0.12))
                                        .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exchangeService.isUsingCachedRates ? "Using Cached Rates" : "Live Exchange Rates Active")
                                            .modifier(InterFont(.semiBold, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                        Text(exchangeService.lastUpdatedLabel)
                                            .modifier(InterFont(.regular, size: 11))
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                    Spacer()
                                    
                                    Button(action: { exchangeService.refresh() }) {
                                         Image(systemName: "arrow.clockwise")
                                             .font(.system(size: 14, weight: .semibold))
                                             .foregroundColor(Color.main_color)
                                             .padding(8)
                                             .background(Color.main_color.opacity(0.12))
                                             .cornerRadius(8)
                                     }
                                }
                                .padding(14)
                                .background(Color.secondary_color)
                                .cornerRadius(12)
                            }
                            
                            // ── CATEGORY BUDGETS ──
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("CATEGORY BUDGETS")
                                        .modifier(InterFont(.semiBold, size: 11))
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text("Tap category to edit")
                                        .modifier(InterFont(.regular, size: 10))
                                        .foregroundColor(Color.text_secondary_color)
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(tagOptions, id: \.self) { tagKey in
                                    BudgetProgressView(tag: tagKey, spentConverted: 0, displayCurrency: viewModel.displayCurrency)
                                        .environmentObject(budgetManager)
                                        .onTapGesture {
                                            selectedBudgetTag = tagKey
                                        }
                                }
                            }
                            
                            // ── ACCOUNT & CLOUD SYNC SECTION ──
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ACCOUNT & CLOUD")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                if !authManager.isAuthenticated {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "icloud.and.arrow.up.fill")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(Color.main_color)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Cloud Backup & Sync")
                                                    .modifier(InterFont(.semiBold, size: 14))
                                                    .foregroundColor(Color.text_primary_color)
                                                Text("Sign in with Apple to sync expenses across your devices.")
                                                    .modifier(InterFont(.regular, size: 12))
                                                    .foregroundColor(Color.text_secondary_color)
                                            }
                                        }
                                        
                                        SignInWithAppleButton(
                                            .signIn,
                                            onRequest: { request in
                                                request.requestedScopes = [.fullName, .email]
                                            },
                                            onCompletion: { result in
                                                switch result {
                                                case .success(let auth):
                                                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                                        authManager.handleSuccessfulAuth(
                                                            userIdentifier: credential.user,
                                                            email: credential.email,
                                                            fullName: credential.fullName
                                                        )
                                                    }
                                                case .failure(let error):
                                                    print("⚠️ Sign in error: \(error.localizedDescription)")
                                                }
                                            }
                                        )
                                        .signInWithAppleButtonStyle(themeManager.isDarkMode ? .white : .black)
                                        .frame(height: 44)
                                        .cornerRadius(10)
                                    }
                                    .padding(14)
                                    .background(Color.secondary_color)
                                    .cornerRadius(12)
                                } else {
                                    Button(action: { showSignOutAlert = true }) {
                                        HStack {
                                            Image(systemName: "applelogo")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color.main_color)
                                                .frame(width: 36, height: 36)
                                                .background(Color.main_color.opacity(0.12))
                                                .cornerRadius(10)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(authManager.userEmail ?? "Signed in with Apple")
                                                    .modifier(InterFont(.semiBold, size: 14))
                                                    .foregroundColor(Color.text_primary_color)
                                                Text("☁️ CloudKit Sync Active")
                                                    .modifier(InterFont(.medium, size: 12))
                                                    .foregroundColor(Color.main_color)
                                            }
                                            Spacer()
                                            Text("Sign Out")
                                                .modifier(InterFont(.semiBold, size: 13))
                                                .foregroundColor(Color.main_red)
                                        }
                                        .padding(14)
                                        .background(Color.secondary_color)
                                        .cornerRadius(12)
                                    }
                                    .alert(isPresented: $showSignOutAlert) {
                                        Alert(
                                            title: Text("Sign Out"),
                                            message: Text("Are you sure you want to sign out? Your local data will remain saved on this device."),
                                            primaryButton: .destructive(Text("Sign Out")) {
                                                authManager.signOut()
                                            },
                                            secondaryButton: .cancel()
                                        )
                                    }
                                }
                            }
                            
                            // ── APP INFO SECTION ──
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ABOUT")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                HStack {
                                    TextView(text: "App Version", type: .button)
                                        .foregroundColor(Color.text_primary_color)
                                    Spacer()
                                    TextView(text: viewModel.appVersion, type: .body_1)
                                        .foregroundColor(Color.text_secondary_color)
                                }
                                .padding(14)
                                .background(Color.secondary_color)
                                .cornerRadius(12)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .sheet(isPresented: Binding<Bool>(
                get: { selectedBudgetTag != nil },
                set: { if !$0 { selectedBudgetTag = nil } }
            )) {
                if let tagKey = selectedBudgetTag {
                    SetCategoryBudgetSheetView(
                        tag: tagKey,
                        currentLimit: budgetManager.limit(for: tagKey) ?? 0,
                        displayCurrency: viewModel.displayCurrency
                    ) { newLimit in
                        budgetManager.setLimit(newLimit, for: tagKey)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

struct SetBudgetSheet: View {
    @Binding var monthlyBudget: Double
    var displayCurrency: String
    var onSave: (Double) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var budgetText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Set Monthly Budget")
                    .modifier(InterFont(.bold, size: 18))
                    .foregroundColor(Color.text_primary_color)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.text_secondary_color)
                }
            }
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly Budget Amount (\(displayCurrency))")
                    .modifier(InterFont(.medium, size: 13))
                    .foregroundColor(Color.text_secondary_color)
                
                HStack {
                    Text(symbolFor(currencyCode: displayCurrency))
                        .modifier(InterFont(.semiBold, size: 18))
                        .foregroundColor(Color.main_color)
                        .padding(.leading, 12)
                    
                    TextField("Budget Amount", text: $budgetText)
                        .modifier(InterFont(.semiBold, size: 18))
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 14)
                }
                .background(Color.secondary_color)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.main_color.opacity(0.2), lineWidth: 1))
            }
            
            Button(action: {
                if let val = Double(budgetText), val > 0 {
                    monthlyBudget = val
                    onSave(val)
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Text("Save Budget")
                    .modifier(InterFont(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.main_color)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.primary_color.edgesIgnoringSafeArea(.all))
        .onAppear {
            budgetText = String(format: "%.0f", monthlyBudget)
        }
    }
}
