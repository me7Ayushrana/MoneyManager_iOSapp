//
//  ExpenseSettingsView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

struct ExpenseSettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    @EnvironmentObject var budgetManager: BudgetManager
    
    @ObservedObject private var viewModel = ExpenseSettingsViewModel()
    @State private var selectDisplayCurrency = false
    @State private var selectedBudgetTag: String? = nil
    
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
                                            viewModel.saveDisplayCurrency(code: curr.code)
                                        }
                                    }
                                    buttons.append(.cancel())
                                    return ActionSheet(title: Text("Display Currency"), message: Text("All summaries, totals, and charts will convert into this currency"), buttons: buttons)
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
                                        Text(exchangeService.isUsingCachedRates ? "Using Cached Rates" : "Rates Live & Up to Date")
                                            .modifier(InterFont(.semiBold, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                        Text(exchangeService.lastUpdatedLabel)
                                            .modifier(InterFont(.regular, size: 11))
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { exchangeService.refresh() }) {
                                        Text("Refresh")
                                            .modifier(InterFont(.semiBold, size: 12))
                                            .foregroundColor(Color.main_color)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(14)
                                .background(Color.secondary_color)
                                .cornerRadius(12)
                            }
                            
                            // ── CATEGORY BUDGET GOALS ──
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MONTHLY BUDGET GOALS")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                VStack(spacing: 8) {
                                    ForEach(tagOptions, id: \.self) { tag in
                                        let currentLimit = budgetManager.limit(for: tag) ?? 0.0
                                        Button(action: { selectedBudgetTag = tag }) {
                                            HStack {
                                                Image(getTransTagIcon(transTag: tag))
                                                    .resizable().scaledToFit()
                                                    .frame(width: 24, height: 24)
                                                    .padding(6)
                                                    .background(Color.main_color.opacity(0.12))
                                                    .cornerRadius(8)
                                                
                                                Text(getTransTagTitle(transTag: tag))
                                                    .modifier(InterFont(.medium, size: 14))
                                                    .foregroundColor(Color.text_primary_color)
                                                
                                                Spacer()
                                                
                                                if currentLimit > 0 {
                                                    CurrencyAmountView(amount: currentLimit, currencyCode: viewModel.displayCurrency, amountType: .caption, codeType: .caption, color: Color.main_color)
                                                } else {
                                                    Text("Not set")
                                                        .modifier(InterFont(.regular, size: 12))
                                                        .foregroundColor(Color.text_secondary_color)
                                                }
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundColor(Color.text_secondary_color)
                                            }
                                            .padding(12)
                                            .background(Color.secondary_color)
                                            .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                            
                            // ── DATA EXPORT ──
                            VStack(alignment: .leading, spacing: 8) {
                                Text("DATA")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                    .padding(.horizontal, 4)
                                
                                Button(action: { viewModel.exportTransactions(moc: managedObjectContext, exchangeService: exchangeService) }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color.main_color)
                                            .frame(width: 36, height: 36)
                                            .background(Color.main_color.opacity(0.12))
                                            .cornerRadius(10)
                                        TextView(text: "Export Transactions (CSV)", type: .button)
                                            .foregroundColor(Color.text_primary_color)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.text_secondary_color)
                                    }
                                    .padding(14)
                                    .background(Color.secondary_color)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Spacer().frame(height: 50)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                    }
                    .alert(isPresented: $viewModel.showAlert) {
                        Alert(title: Text(APP_NAME), message: Text(viewModel.alertMsg), dismissButton: .default(Text("OK")))
                    }
                }
                .edgesIgnoringSafeArea(.top)
            }
            .sheet(item: Binding<BudgetTagItem?>(
                get: { selectedBudgetTag.map { BudgetTagItem(tag: $0) } },
                set: { selectedBudgetTag = $0?.tag }
            )) { item in
                SetBudgetSheet(
                    tag: item.tag,
                    currentLimit: budgetManager.limit(for: item.tag) ?? 0.0,
                    displayCurrency: viewModel.displayCurrency
                ) { newLimit in
                    budgetManager.setLimit(newLimit, for: item.tag)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

struct BudgetTagItem: Identifiable {
    var tag: String
    var id: String { tag }
}
