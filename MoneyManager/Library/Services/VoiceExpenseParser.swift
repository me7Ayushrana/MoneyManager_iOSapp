//
//  VoiceExpenseParser.swift
//  MoneyManager
//
//  Created for TrackMint.
//  High-precision NLP voice parser extracting amount, currency, date, transaction type, and category.
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
    
    /// Parses spoken text e.g. "spent 200 rupees on coffee today", "5k for grocery yesterday", "received 45000 salary".
    func parse(_ rawText: String, defaultCurrency: String) -> ParsedVoiceExpense {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedVoiceExpense(rawText: rawText, amount: nil, currencyCode: defaultCurrency, date: Date(), title: "", suggestedTagKey: nil, transactionType: TRANS_TYPE_EXPENSE, isSuccess: false)
        }
        
        var workingText = trimmed
        
        // 1. Transaction Type Intent (Income vs Expense)
        let transactionType = extractTransactionType(from: workingText)
        
        // 2. Date Reference ("yesterday", "today", "day before yesterday")
        let (extractedDate, textAfterDate) = extractDate(from: workingText)
        workingText = textAfterDate
        
        // 3. Currency Code Extraction ("rupees", "inr", "rs", "dollars", "bucks", "euros", etc.)
        let (extractedCurrency, textAfterCurrency) = extractCurrency(from: workingText, defaultCurrency: defaultCurrency)
        workingText = textAfterCurrency
        
        // 4. Amount Extraction (handles numbers, "5k", "10k", "1 lakh", and number words)
        let (extractedAmount, textAfterAmount) = extractAmount(from: workingText)
        workingText = textAfterAmount
        
        // 5. Title Cleaning & Smart Category Suggestion
        let cleanTitle = cleanTitleDescription(from: workingText)
        
        var suggestedTagKey: String? = nil
        let targetForCategory = cleanTitle.isEmpty ? trimmed : cleanTitle
        let suggestions = SmartCategoryManager.shared.suggestCategories(for: targetForCategory, limit: 1)
        suggestedTagKey = suggestions.first?.tagKey
        
        let success = extractedAmount != nil
        let finalTitle = cleanTitle.isEmpty ? (success ? "Transaction" : trimmed) : cleanTitle
        
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
    
    // MARK: - Transaction Type Intent
    
    private func extractTransactionType(from text: String) -> String {
        let lower = text.lowercased()
        let incomeKeywords = ["earned", "earning", "received", "salary", "credited", "income", "got paid", "cashback", "refund", "stipend", "deposit", "freelance", "profit", "gift"]
        for kw in incomeKeywords {
            if lower.contains(kw) {
                return TRANS_TYPE_INCOME
            }
        }
        return TRANS_TYPE_EXPENSE
    }
    
    // MARK: - Amount Extraction
    
    private func extractAmount(from text: String) -> (Double?, String) {
        var working = text
        
        // 1. Match numbers with multipliers e.g. "5k" -> 5000, "1.5k" -> 1500, "1 lakh" -> 100000
        let multiplierPattern = #"\b(\d+(?:\.\d+)?)\s*(k|thousand|lakh|lac)\b"#
        if let regex = try? NSRegularExpression(pattern: multiplierPattern, options: [.caseInsensitive]) {
            let nsString = working as NSString
            if let match = regex.firstMatch(in: working, options: [], range: NSRange(location: 0, length: nsString.length)) {
                let numStr = nsString.substring(with: match.range(at: 1))
                let unitStr = nsString.substring(with: match.range(at: 2)).lowercased()
                
                if let val = Double(numStr) {
                    var finalVal = val
                    if unitStr == "k" || unitStr == "thousand" {
                        finalVal = val * 1000.0
                    } else if unitStr == "lakh" || unitStr == "lac" {
                        finalVal = val * 100000.0
                    }
                    let remaining = nsString.replacingCharacters(in: match.range, with: " ")
                    return (finalVal, remaining)
                }
            }
        }
        
        // 2. Standard numbers e.g. 200, 350.50, 1500
        let numberPattern = #"\b\d+(?:\.\d{1,2})?\b"#
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let nsString = working as NSString
            let matches = regex.matches(in: working, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Return first sensible amount
            for match in matches {
                let matchedStr = nsString.substring(with: match.range)
                if let val = Double(matchedStr), val > 0 {
                    let remaining = nsString.replacingCharacters(in: match.range, with: " ")
                    return (val, remaining)
                }
            }
        }
        
        // 3. Spoken number words e.g. "twenty", "fifty", "hundred"
        let numberWords: [String: Double] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90, "hundred": 100, "thousand": 1000
        ]
        
        let words = working.components(separatedBy: .whitespaces)
        for (idx, word) in words.enumerated() {
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let val = numberWords[lower] {
                var mutableWords = words
                mutableWords.remove(at: idx)
                return (val, mutableWords.joined(separator: " "))
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
            "spent", "pay", "paid", "bought", "got", "for", "on", "at", "amount", "cost", "price", "of", "and", "the", "a", "an", "rs", "rupee", "rupees", "inr", "dollar", "dollars", "usd"
        ]
        
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !fillerWords.contains($0.lowercased()) && !$0.isEmpty }
        
        let cleaned = words.joined(separator: " ")
        return cleaned.capitalized
    }
}
