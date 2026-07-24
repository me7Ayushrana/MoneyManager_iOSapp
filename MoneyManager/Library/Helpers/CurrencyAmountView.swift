//
//  CurrencyAmountView.swift
//  MoneyManager
//
//  Reusable component that renders a currency symbol/code in a smaller
//  secondary font alongside the numeric amount in a larger primary font.
//  Use this everywhere an amount is displayed — never format amounts inline.
//

import SwiftUI

struct CurrencyAmountView: View {
    
    var amount: Double
    var currencyCode: String          // ISO code e.g. "USD", "INR"
    var amountType: TextView_Type     // controls size of the number
    var codeType: TextView_Type       // controls size of the symbol (use .caption or .overline)
    var color: Color                  // applied to both parts
    var showOriginal: Bool            // if true, show original; false = converted presentation
    var prefix: String                // optional prefix: "+", "-", ""
    
    init(amount: Double,
         currencyCode: String,
         amountType: TextView_Type = .subtitle_1,
         codeType: TextView_Type = .caption,
         color: Color = Color.text_primary_color,
         showOriginal: Bool = true,
         prefix: String = "") {
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountType = amountType
        self.codeType = codeType
        self.color = color
        self.showOriginal = showOriginal
        self.prefix = prefix
    }
    
    private var symbol: String { symbolFor(currencyCode: currencyCode) }
    
    private var amountText: String {
        let formatted = String(format: "%.2f", abs(amount))
        return "\(prefix)\(formatted)"
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            // Currency symbol — smaller, secondary
            TextView(text: symbol, type: codeType)
                .foregroundColor(color.opacity(0.75))
            
            // Numeric amount — larger, primary
            TextView(text: amountText, type: amountType)
                .foregroundColor(color)
        }
    }
}

// MARK: - Convenience init for transaction rows (income/expense coloring)

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
    
    /// Creates a large hero amount for the dashboard total card.
    static func forHero(amount: Double, currencyCode: String) -> CurrencyAmountView {
        CurrencyAmountView(
            amount: amount,
            currencyCode: currencyCode,
            amountType: .h5,
            codeType: .subtitle_2,
            color: Color.text_primary_color
        )
    }
    
    /// Creates an amount for the income/expense summary cards.
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
