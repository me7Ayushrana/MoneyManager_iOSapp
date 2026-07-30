//
//  CalculatorView.swift
//  MoneyManager
//
//  Quick math accessory keyboard / pad for evaluating expressions directly
//  when entering or editing transaction amounts (+, -, ×, ÷, =, AC, ⌫).
//

import SwiftUI

struct CalculatorView: View {
    @Binding var amountText: String
    var onDone: (() -> Void)? = nil
    
    @State private var expressionText: String = ""
    @State private var hasEvaluated: Bool = false
    
    let buttons: [[String]] = [
        ["AC", "⌫", "÷", "×"],
        ["7", "8", "9", "-"],
        ["4", "5", "6", "+"],
        ["1", "2", "3", "="],
        ["0", ".", "DONE"]
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Live expression preview header
            HStack {
                Text(expressionText.isEmpty ? (amountText.isEmpty ? "0" : amountText) : expressionText)
                    .modifier(InterFont(.semiBold, size: 16))
                    .foregroundColor(Color.text_primary_color)
                    .lineLimit(1)
                Spacer()
                if !expressionText.isEmpty {
                    Text("= \(evaluate(expressionText))")
                        .modifier(InterFont(.bold, size: 16))
                        .foregroundColor(Color.main_color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.primary_color)
            .cornerRadius(8)
            
            // Grid of buttons
            VStack(spacing: 6) {
                ForEach(buttons, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { btn in
                            Button(action: { buttonTapped(btn) }) {
                                Text(btn)
                                    .modifier(InterFont(.semiBold, size: btn == "DONE" ? 13 : 16))
                                    .foregroundColor(buttonTextColor(btn))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(buttonBgColor(btn))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary_color)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.main_color.opacity(0.2), lineWidth: 1))
        .onAppear {
            expressionText = amountText
        }
    }
    
    private func buttonTapped(_ btn: String) {
        switch btn {
        case "AC":
            expressionText = ""
            amountText = ""
            hasEvaluated = false
        case "⌫":
            if !expressionText.isEmpty {
                expressionText.removeLast()
            }
        case "=":
            let result = evaluate(expressionText)
            if !result.isEmpty && result != "Error" {
                amountText = result
                expressionText = result
                hasEvaluated = true
            }
        case "DONE":
            let result = evaluate(expressionText)
            if !result.isEmpty && result != "Error" {
                amountText = result
            }
            onDone?()
        case "+", "-", "×", "÷":
            if hasEvaluated {
                hasEvaluated = false
            }
            if expressionText.isEmpty {
                expressionText = amountText
            }
            if let last = expressionText.last, ["+", "-", "×", "÷"].contains(String(last)) {
                expressionText.removeLast()
            }
            expressionText += btn
        default: // Numbers 0-9 & dot
            if hasEvaluated {
                expressionText = btn
                hasEvaluated = false
            } else {
                expressionText += btn
            }
            let liveResult = evaluate(expressionText)
            if !liveResult.isEmpty && liveResult != "Error" {
                amountText = liveResult
            }
        }
    }
    
    private func evaluate(_ expr: String) -> String {
        guard !expr.isEmpty else { return "" }
        var sanitized = expr.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
        
        // Remove trailing operators for safe parsing
        while let last = sanitized.last, ["+", "-", "*", "/"].contains(String(last)) {
            sanitized.removeLast()
        }
        guard !sanitized.isEmpty else { return "" }
        
        let expression = NSExpression(format: sanitized)
        if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            let val = result.doubleValue
            if val < 0 { return "0" }
            return val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.2f", val)
        }
        return ""
    }
    
    private func buttonTextColor(_ btn: String) -> Color {
        switch btn {
        case "DONE", "=": return .white
        case "AC", "⌫": return Color.main_red
        case "+", "-", "×", "÷": return Color.main_color
        default: return Color.text_primary_color
        }
    }
    
    private func buttonBgColor(_ btn: String) -> Color {
        switch btn {
        case "DONE", "=": return Color.main_color
        case "AC", "⌫": return Color.main_red.opacity(0.12)
        case "+", "-", "×", "÷": return Color.main_color.opacity(0.12)
        default: return Color.primary_color
        }
    }
}
