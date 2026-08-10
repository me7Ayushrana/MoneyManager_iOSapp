//
//  ReceiptScannerService.swift
//  MoneyManager
//
//  Created for TrackMint.
//  On-device Vision framework OCR service for extracting merchant, total amount, date, and category from receipt images.
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
    
    /// Processes a UIImage of a receipt using Vision OCR (VNRecognizeTextRequest) and parses key receipt fields.
    func processReceiptImage(_ image: UIImage, completion: @escaping (ParsedReceipt) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                DispatchQueue.main.async {
                    completion(ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false))
                }
                return
            }
            
            // Extract top candidates ordered vertically by position (top to bottom)
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
    
    /// Parses an array of recognized text lines into a ParsedReceipt struct.
    func parseTextLines(_ lines: [String]) -> ParsedReceipt {
        let fullRawText = lines.joined(separator: "\n")
        guard !lines.isEmpty else {
            return ParsedReceipt(merchantName: nil, totalAmount: nil, date: nil, rawText: "", suggestedTagKey: nil, isSuccess: false)
        }
        
        let merchantName = extractMerchantName(from: lines)
        let totalAmount = extractTotalAmount(from: lines)
        let date = extractDate(from: lines)
        
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
            "time:", "table", "guest", "order", "store", "duplicate", "original", "copy", "www."
        ]
        
        for line in lines.prefix(4) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            
            if trimmed.count >= 3 && !ignoreKeywords.contains(where: { lower.contains($0) }) {
                return trimmed.capitalized
            }
        }
        
        return nil
    }
    
    // MARK: - Total Amount Extraction
    
    private func extractTotalAmount(from lines: [String]) -> Double? {
        let totalKeywords = ["grand total", "total due", "amount due", "balance due", "total", "net total", "payment", "paid", "amount paid"]
        let numberRegex = #"\b\d+(?:[\.,]\d{2})?\b"#
        
        // 1. First search lines bottom-to-top matching total keywords
        for line in lines.reversed() {
            let lower = line.lowercased()
            if totalKeywords.contains(where: { lower.contains($0) }) {
                if let val = extractLargestNumber(from: line, regexPattern: numberRegex) {
                    return val
                }
            }
        }
        
        // 2. Fallback: Search all lines for decimal formatted numbers and pick maximum sensible value
        var candidates: [Double] = []
        for line in lines {
            if let val = extractLargestNumber(from: line, regexPattern: numberRegex) {
                if val > 0.0 && val < 100_000 {
                    candidates.append(val)
                }
            }
        }
        
        return candidates.max()
    }
    
    private func extractLargestNumber(from text: String, regexPattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var numbers: [Double] = []
        for match in matches {
            let strVal = nsString.substring(with: match.range).replacingOccurrences(of: ",", with: ".")
            if let dbl = Double(strVal) {
                numbers.append(dbl)
            }
        }
        
        return numbers.max()
    }
    
    // MARK: - Date Extraction
    
    private func extractDate(from lines: [String]) -> Date? {
        let datePattern = #"\b(?:\d{1,2}[/\.-]\d{1,2}[/\.-]\d{2,4}|\d{4}[/\.-]\d{1,2}[/\.-]\d{1,2}|(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2},? \d{4})\b"#
        
        guard let regex = try? NSRegularExpression(pattern: datePattern, options: [.caseInsensitive]) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let dateFormats = ["MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "MM-dd-yyyy", "dd MMM yyyy", "MMM dd, yyyy"]
        
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
}
