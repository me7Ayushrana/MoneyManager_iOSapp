//
//  BudgetProgressView.swift
//  MoneyManager
//
//  Progress bar component for category budget goals.
//  Shows progress: green < 70%, amber 70-100%, red > 100%.
//

import SwiftUI

struct BudgetProgressView: View {
    var tag: String
    var spentConverted: Double
    var displayCurrency: String
    
    @EnvironmentObject var budgetManager: BudgetManager
    @State private var showSetBudgetSheet = false
    @State private var inputBudget = ""
    
    var body: some View {
        let progress = budgetManager.progress(for: tag, spent: spentConverted)
        let statusColor = Color(hex: progress.status.color)
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONTHLY BUDGET")
                        .modifier(InterFont(.semiBold, size: 11))
                        .foregroundColor(Color.text_secondary_color)
                    if progress.limit > 0 {
                        HStack(spacing: 4) {
                            CurrencyAmountView(amount: progress.spent, currencyCode: displayCurrency, amountType: .subtitle_1, codeType: .caption, color: Color.text_primary_color)
                            Text("of")
                                .modifier(InterFont(.regular, size: 12))
                                .foregroundColor(Color.text_secondary_color)
                            CurrencyAmountView(amount: progress.limit, currencyCode: displayCurrency, amountType: .subtitle_1, codeType: .caption, color: Color.text_secondary_color)
                        }
                    } else {
                        Text("No budget set for this category")
                            .modifier(InterFont(.regular, size: 13))
                            .foregroundColor(Color.text_secondary_color)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    inputBudget = progress.limit > 0 ? String(format: "%.2f", progress.limit) : ""
                    showSetBudgetSheet = true
                }) {
                    Text(progress.limit > 0 ? "Edit" : "Set Goal")
                        .modifier(InterFont(.semiBold, size: 12))
                        .foregroundColor(Color.main_color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.main_color.opacity(0.12))
                        .cornerRadius(12)
                }
            }
            
            if progress.limit > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary_color)
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(statusColor)
                            .frame(width: min(geo.size.width * CGFloat(min(progress.fraction, 1.0)), geo.size.width), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(progress.percentageText) used")
                        .modifier(InterFont(.semiBold, size: 11))
                        .foregroundColor(statusColor)
                    
                    Spacer()
                    
                    if progress.status == .exceeded {
                        Text("Over budget!")
                            .modifier(InterFont(.bold, size: 11))
                            .foregroundColor(Color.main_red)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondary_color)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(progress.limit > 0 ? statusColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .sheet(isPresented: $showSetBudgetSheet) {
            SetCategoryBudgetSheetView(tag: tag, currentLimit: progress.limit, displayCurrency: displayCurrency) { newLimit in
                budgetManager.setLimit(newLimit, for: tag)
            }
        }
    }
}

struct SetCategoryBudgetSheetView: View {
    var tag: String
    var currentLimit: Double
    var displayCurrency: String
    var onSave: (Double) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var amountText: String = ""
    
    init(tag: String, currentLimit: Double, displayCurrency: String, onSave: @escaping (Double) -> Void) {
        self.tag = tag
        self.currentLimit = currentLimit
        self.displayCurrency = displayCurrency
        self.onSave = onSave
        _amountText = State(initialValue: currentLimit > 0 ? String(format: "%.2f", currentLimit) : "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Monthly Budget for \(getTransTagTitle(transTag: tag))")
                    .modifier(InterFont(.bold, size: 16))
                    .foregroundColor(Color.text_primary_color)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.text_secondary_color)
                }
            }
            .padding(.top, 20)
            
            HStack(spacing: 0) {
                Text(symbolFor(currencyCode: displayCurrency))
                    .modifier(InterFont(.semiBold, size: 18))
                    .foregroundColor(Color.main_color)
                    .frame(width: 44, height: 50)
                    .background(Color.main_color.opacity(0.12))
                
                TextField("Amount (0 to clear)", text: $amountText)
                    .modifier(InterFont(.regular, size: 16))
                    .accentColor(Color.text_primary_color)
                    .frame(height: 50).padding(.leading, 12)
                    .keyboardType(.decimalPad)
            }
            .background(Color.secondary_color)
            .cornerRadius(8)
            
            Button(action: {
                let limit = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
                onSave(limit)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Save Budget Goal")
                    .modifier(InterFont(.semiBold, size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.main_color)
                    .cornerRadius(10)
            }
            
            if currentLimit > 0 {
                Button(action: {
                    onSave(0)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Remove Budget")
                        .modifier(InterFont(.medium, size: 14))
                        .foregroundColor(Color.main_red)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.primary_color.edgesIgnoringSafeArea(.all))
    }
}
