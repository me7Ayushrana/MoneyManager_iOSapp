//
//  VoiceExpenseParser.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Rule-based NLP parser extracting amount, currency, date references, and title description from transcribed voice text.
//

import Foundation

struct ParsedVoiceExpense {
    let rawText: String
    let amount: Double?
    let currencyCode: String?
    let date: Date
    let title: String
    let suggestedTagKey: String?
    let transactionType: String
    let isSuccess: Bool
}

class VoiceExpenseParser {
    
    static let shared = VoiceExpenseParser()
    
    private init() {}
    
    /// Parses a raw spoken transcription string e.g. "spent 200 rupees on coffee today" or "300 on Swiggy yesterday".
    func parse(_ rawText: String, defaultCurrency: String) -> ParsedVoiceExpense {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedVoiceExpense(rawText: rawText, amount: nil, currencyCode: defaultCurrency, date: Date(), title: "", suggestedTagKey: nil, transactionType: TRANS_TYPE_EXPENSE, isSuccess: false)
        }
        
        var workingText = trimmed
        
        // 0. Detect Expense vs Income transaction type intent
        let transactionType = extractTransactionType(from: workingText)
        
        // 1. Extract Date reference
        let (extractedDate, textAfterDate) = extractDate(from: workingText)
        workingText = textAfterDate
        
        // 2. Extract Currency code & strip currency words
        let (extractedCurrency, textAfterCurrency) = extractCurrency(from: workingText, defaultCurrency: defaultCurrency)
        workingText = textAfterCurrency
        
        // 3. Extract Amount
        let (extractedAmount, textAfterAmount) = extractAmount(from: workingText)
        workingText = textAfterAmount
        
        // 4. Clean up remaining title tokens
        let cleanTitle = cleanTitleDescription(from: workingText)
        
        // 5. Run title through existing SmartCategoryManager NLEmbedding suggestion logic
        var suggestedTagKey: String? = nil
        if !cleanTitle.isEmpty {
            let suggestions = SmartCategoryManager.shared.suggestCategories(for: cleanTitle, limit: 1)
            suggestedTagKey = suggestions.first?.tagKey
        }
        
        let success = extractedAmount != nil
        let finalTitle = success ? (cleanTitle.isEmpty ? trimmed : cleanTitle) : trimmed
        
        return ParsedVoiceExpense(
            rawText: trimmed,
            amount: extractedAmount,
            currencyCode: extractedCurrency,
            date: extractedDate,
            title: finalTitle,
            suggestedTagKey: suggestedTagKey,
            transactionType: transactionType,
            isSuccess: success
        )
    }
    
    private func extractTransactionType(from text: String) -> String {
        let lower = text.lowercased()
        let incomeKeywords = ["earned", "earning", "received", "salary", "credited", "income", "got paid", "cashback", "refund", "stipend", "deposit", "gain", "freelance"]
        for kw in incomeKeywords {
            if lower.contains(kw) {
                return TRANS_TYPE_INCOME
            }
        }
        return TRANS_TYPE_EXPENSE
    }
    
    // MARK: - Amount Extraction
    
    private func extractAmount(from text: String) -> (Double?, String) {
        // Match numbers e.g. 200, 300.50, 1500
        let pattern = #"\b\d+(?:\.\d{1,2})?\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let matchedStr = nsString.substring(with: match.range)
                if let val = Double(matchedStr) {
                    let remaining = nsString.replacingCharacters(in: match.range, with: " ")
                    return (val, remaining)
                }
            }
        }
        
        // Match number words e.g. "twenty", "fifty", "hundred"
        let numberWords: [String: Double] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90, "hundred": 100, "thousand": 1000
        ]
        
        var words = text.components(separatedBy: .whitespaces)
        for (idx, word) in words.enumerated() {
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let val = numberWords[lower] {
                words.remove(at: idx)
                return (val, words.joined(separator: " "))
            }
        }
        
        return (nil, text)
    }
    
    // MARK: - Currency Extraction
    
    private func extractCurrency(from text: String, defaultCurrency: String) -> (String, String) {
        let currencyMap: [String: [String]] = [
            "INR": ["rupee", "rupees", "inr", "₹", "rs", "rs."],
            "USD": ["dollar", "dollars", "usd", "$", "bucks"],
            "EUR": ["euro", "euros", "eur", "€"],
            "GBP": ["pound", "pounds", "gbp", "£"],
            "JPY": ["yen", "jpy", "¥"],
            "AED": ["dirham", "dirhams", "aed"],
            "CAD": ["cad", "canadian dollar"],
            "AUD": ["aud", "australian dollar"],
            "SGD": ["sgd", "singapore dollar"]
        ]
        
        var working = text
        var matchedCode: String? = nil
        
        for (code, keywords) in currencyMap {
            for kw in keywords {
                let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: kw) + #"\b"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsString = working as NSString
                    if let match = regex.firstMatch(in: working, options: [], range: NSRange(location: 0, length: nsString.length)) {
                        matchedCode = code
                        working = nsString.replacingCharacters(in: match.range, with: " ")
                        break
                    }
                }
            }
            if matchedCode != nil { break }
        }
        
        return (matchedCode ?? defaultCurrency, working)
    }
    
    // MARK: - Date Extraction
    
    private func extractDate(from text: String) -> (Date, String) {
        var working = text
        let lower = text.lowercased()
        let cal = Calendar.current
        let today = Date()
        
        if lower.contains("day before yesterday") {
            working = replace(word: "day before yesterday", in: working)
            if let date = cal.date(byAdding: .day, value: -2, to: today) { return (date, working) }
        } else if lower.contains("yesterday") {
            working = replace(word: "yesterday", in: working)
            if let date = cal.date(byAdding: .day, value: -1, to: today) { return (date, working) }
        } else if lower.contains("today") {
            working = replace(word: "today", in: working)
            return (today, working)
        }
        
        return (today, working)
    }
    
    // MARK: - Helper Cleaners
    
    private func replace(word: String, in text: String) -> String {
        let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsString = text as NSString
            return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: " ")
        }
        return text
    }
    
    private func cleanTitleDescription(from text: String) -> String {
        let fillerWords: Set<String> = [
            "spent", "pay", "paid", "bought", "got", "for", "on", "at", "amount", "cost", "price", "of", "and", "the", "a", "an"
        ]
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !fillerWords.contains($0.lowercased()) && !$0.isEmpty }
        
        let cleaned = words.joined(separator: " ")
        return cleaned.capitalized
    }
}
