//
//  ReceiptScannerService.swift
//  MoneyManager
//
//  Created for TrackMint.
//  High-accuracy Vision framework OCR service for extracting merchant, total amount, date, and category from receipt images.
//

import Foundation
import UIKit
import Vision

struct ParsedReceipt {
    let merchantName: String?
    let totalAmount: Double?
    let date: Date?
    let rawText: String
    let suggestedTagKey: String?
    let isSuccess: Bool
}

class ReceiptScannerService {
    
    static let shared = ReceiptScannerService()
    
    private init() {}
    
    /// Processes a UIImage of a receipt using Vision OCR (VNRecognizeTextRequest) with orientation awareness.
    func processReceiptImage(_ image: UIImage, completion: @escaping (ParsedReceipt) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false))
            return
        }
        
        let orientation = cgImageOrientation(from: image.imageOrientation)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    completion(ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false))
                }
                return
            }
            
            // Extract top candidate string from each observation
            let lines: [String] = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let parsed = self.parseTextLines(lines)
            DispatchQueue.main.async {
                completion(parsed)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false))
                }
            }
        }
    }
    
    /// Parses array of recognized text lines into ParsedReceipt.
    func parseTextLines(_ lines: [String]) -> ParsedReceipt {
        let cleanedLines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let fullRawText = cleanedLines.joined(separator: "\n")
        
        guard !cleanedLines.isEmpty else {
            return ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false)
        }
        
        let merchantName = extractMerchantName(from: cleanedLines)
        let totalAmount = extractTotalAmount(from: cleanedLines)
        let date = extractDate(from: cleanedLines)
        
        var suggestedTagKey: String? = nil
        if let merchant = merchantName {
            let suggestions = SmartCategoryManager.shared.suggestCategories(for: merchant, limit: 1)
            suggestedTagKey = suggestions.first?.tagKey
        }
        
        let isSuccess = totalAmount != nil || merchantName != nil
        
        return ParsedReceipt(
            merchantName: merchantName,
            totalAmount: totalAmount,
            date: date,
            rawText: fullRawText,
            suggestedTagKey: suggestedTagKey,
            isSuccess: isSuccess
        )
    }
    
    // MARK: - Merchant Name Extraction
    
    private func extractMerchantName(from lines: [String]) -> String? {
        let ignoreKeywords: Set<String> = [
            "receipt", "tax invoice", "invoice", "welcome", "tel:", "phone:", "cashier", "date:",
            "time:", "table", "guest", "order", "store", "duplicate", "original", "copy", "www.",
            "http", "gstin", "vat", "pos", "terminal", "card", "visa", "mastercard"
        ]
        
        for line in lines.prefix(6) {
            let lower = line.lowercased()
            
            // Skip lines with numbers only, dates, or ignored receipt header terms
            if line.count >= 3 &&
                !ignoreKeywords.contains(where: { lower.contains($0) }) &&
                line.rangeOfCharacter(from: .letters) != nil {
                
                // Clean up trailing punctuation
                let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "-#*:;,."))
                if cleaned.count >= 3 {
                    return cleaned.capitalized
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Total Amount Extraction
    
    private func extractTotalAmount(from lines: [String]) -> Double? {
        let totalKeywords = ["grand total", "total due", "amount due", "balance due", "total amount", "net total", "amount paid", "total:"]
        let secondaryKeywords = ["total", "paid", "payment"]
        let excludeKeywords = ["subtotal", "sub-total", "sub total", "tax", "vat", "cgst", "sgst", "discount", "change", "cash", "items"]
        
        // 1. Search lines matching primary TOTAL keywords bottom-to-top
        for line in lines.reversed() {
            let lower = line.lowercased()
            if totalKeywords.contains(where: { lower.contains($0) }) && !excludeKeywords.contains(where: { lower.contains($0) }) {
                if let val = extractNumberFromLine(line) {
                    return val
                }
            }
        }
        
        // 2. Search lines matching secondary TOTAL keywords
        for line in lines.reversed() {
            let lower = line.lowercased()
            if secondaryKeywords.contains(where: { lower.contains($0) }) && !excludeKeywords.contains(where: { lower.contains($0) }) {
                if let val = extractNumberFromLine(line) {
                    return val
                }
            }
        }
        
        // 3. Fallback: Parse all numbers in receipt and select maximum sensible currency amount
        var candidates: [Double] = []
        for line in lines {
            let lower = line.lowercased()
            if !excludeKeywords.contains(where: { lower.contains($0) }) {
                if let val = extractNumberFromLine(line) {
                    // Ignore phone numbers, zip codes, years (e.g. > 100,000 or year-like 2026)
                    if val > 0.50 && val < 100_000 && val != 2024 && val != 2025 && val != 2026 {
                        candidates.append(val)
                    }
                }
            }
        }
        
        return candidates.max()
    }
    
    private func extractNumberFromLine(_ line: String) -> Double? {
        // Regex matching numbers with optional currency symbols: e.g. $35.52, ₹787.50, Rs. 450, 45.00
        let pattern = #"(?:[$₹€£¥]|Rs\.?|INR|USD|EUR|GBP)?\s*(\d{1,6}(?:[\.,]\d{2})?)\s*(?:[$₹€£¥]|Rs\.?|INR|USD|EUR|GBP)?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsString = line as NSString
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var foundNumbers: [Double] = []
        for match in matches {
            if match.numberOfRanges > 1 {
                let numRange = match.range(at: 1)
                let numStr = nsString.substring(with: numRange).replacingOccurrences(of: ",", with: ".")
                if let val = Double(numStr), val > 0 {
                    foundNumbers.append(val)
                }
            }
        }
        
        return foundNumbers.max()
    }
    
    // MARK: - Date Extraction
    
    private func extractDate(from lines: [String]) -> Date? {
        let datePattern = #"\b(?:\d{1,2}[/\.-]\d{1,2}[/\.-]\d{2,4}|\d{4}[/\.-]\d{1,2}[/\.-]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4}|\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{4})\b"#
        
        guard let regex = try? NSRegularExpression(pattern: datePattern, options: [.caseInsensitive]) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let dateFormats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd MMM yyyy", "MMM dd, yyyy", "dd MMMM yyyy", "MMMM dd, yyyy"]
        
        for line in lines {
            let nsString = line as NSString
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let matchedStr = nsString.substring(with: match.range)
                for fmt in dateFormats {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: matchedStr) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    private func cgImageOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
