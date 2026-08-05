//
//  CurrencyAmountView.swift
//  MoneyManager
//
//  Reusable component that renders currency amounts with perfect sign positioning
//  (e.g., -₹7,777.00 or +₹6,772.69), custom typography, and sign-aware colors.
//

import SwiftUI

struct CurrencyAmountView: View {
    
    var amount: Double
    var currencyCode: String          // ISO code e.g. "USD", "INR"
    var amountType: TextView_Type     // controls size of the number
    var codeType: TextView_Type       // controls size of the symbol
    var color: Color                  // applied to amount & symbol
    var showOriginal: Bool            // if true, show original
    var explicitPrefix: String?       // optional forced prefix: "+", "-", ""
    
    init(amount: Double,
         currencyCode: String,
         amountType: TextView_Type = .subtitle_1,
         codeType: TextView_Type = .caption,
         color: Color = Color.text_primary_color,
         showOriginal: Bool = true,
         prefix: String? = nil) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountType = amountType
        self.codeType = codeType
        self.color = color
        self.showOriginal = showOriginal
        self.explicitPrefix = prefix
    }
    
    private var symbol: String { symbolFor(currencyCode: currencyCode) }
    
    /// Sign prefix: "-" if negative, explicitPrefix if provided, or empty
    private var signPrefix: String {
        if let p = explicitPrefix { return p }
        return amount < 0 ? "-" : ""
    }
    
    private var formattedNumber: String {
        let absVal = abs(amount)
        return String(format: "%.2f", absVal)
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            // Sign + Symbol — smaller, secondary
            TextView(text: "\(signPrefix)\(symbol)", type: codeType)
                .foregroundColor(color.opacity(0.85))
            
            // Numeric amount — larger, primary
            TextView(text: formattedNumber, type: amountType)
                .foregroundColor(color)
        }
    }
}

// MARK: - Convenience Initializers

extension CurrencyAmountView {
    /// Creates a sign-coloured CurrencyAmountView for a transaction row.
    static func forTransaction(amount: Double,
                               currencyCode: String,
                               isIncome: Bool) -> CurrencyAmountView {
        CurrencyAmountView(
            amount: amount,
            currencyCode: currencyCode,
            amountType: .subtitle_1,
            codeType: .caption,
            color: isIncome ? Color.main_green : Color.main_red,
            prefix: isIncome ? "+" : "-"
        )
    }
    
    /// Creates a hero amount for the dashboard total balance card with pure white text and automatic negative red coloring.
    static func forHero(amount: Double, currencyCode: String) -> CurrencyAmountView {
        let color: Color = amount < 0 ? Color.main_red : Color.white
        return CurrencyAmountView(
            amount: amount,
            currencyCode: currencyCode,
            amountType: .h3,
            codeType: .h6,
            color: color
        )
    }
    
    /// Creates an amount for income/expense summary cards.
    static func forSummaryCard(amount: Double,
                               currencyCode: String,
                               isIncome: Bool) -> CurrencyAmountView {
        CurrencyAmountView(
            amount: amount,
            currencyCode: currencyCode,
            amountType: .subtitle_1,
            codeType: .caption,
            color: Color.text_primary_color
        )
    }
}
