//
//  SmartCategoryManager.swift
//  MoneyManager
//
//  Created for TrackMint.
//  On-device smart category recommendation engine powered by Apple's NaturalLanguage NLEmbedding.
//

import Foundation
import SwiftUI
import NaturalLanguage

struct CategorySuggestion: Identifiable, Equatable {
    var id: String { tagKey }
    let tagKey: String
    let tagTitle: String
    let iconName: String
    let score: Double
}

class SmartCategoryManager: ObservableObject {
    
    static let shared = SmartCategoryManager()
    
    /// Category keywords dictionary: [tagKey: [keywords]]
    @Published private(set) var categoryKeywords: [String: [String]] = [:] {
        didSet { persistKeywords() }
    }
    
    private let embedding = NLEmbedding.wordEmbedding(for: .english)
    
    private init() {
        loadKeywords()
    }
    
    // MARK: - Default Keyword Setup
    
    private var defaultKeywords: [String: [String]] {
        [
            TRANS_TAG_FOOD: [
                "restaurant", "swiggy", "zomato", "lunch", "dinner", "breakfast", "coffee", "cafe",
                "starbucks", "pizza", "burger", "subway", "grocery", "supermarket", "food", "eat",
                "snack", "bakery", "kitchen", "bar", "pub", "sushi", "taco", "diner"
            ],
            TRANS_TAG_TRANSPORT: [
                "uber", "ola", "taxi", "cab", "fuel", "petrol", "diesel", "gas", "subway", "metro",
                "bus", "train", "flight", "airline", "parking", "toll", "auto", "vehicle", "commute",
                "ride", "rapido", "lyft", "ticket"
            ],
            TRANS_TAG_HOUSING: [
                "rent", "mortgage", "apartment", "lease", "landlord", "maintenance", "house",
                "repair", "furniture", "appliances", "cleaning", "plumbing", "paint", "roof"
            ],
            TRANS_TAG_UTILITIES: [
                "electricity", "water", "wifi", "internet", "broadband", "phone", "recharge",
                "bill", "power", "utility", "sewer", "trash", "mobile", "postpaid", "dth"
            ],
            TRANS_TAG_ENTERTAINMENT: [
                "movie", "cinema", "netflix", "spotify", "hulu", "disney", "prime", "ticket",
                "concert", "game", "gaming", "steam", "show", "party", "club", "theater", "event"
            ],
            TRANS_TAG_MEDICAL: [
                "doctor", "pharmacy", "hospital", "medicine", "clinic", "dental", "dentist",
                "health", "prescription", "chemist", "lab", "test", "checkup", "pills", "medical"
            ],
            TRANS_TAG_INSURANCE: [
                "policy", "insurance", "premium", "coverage", "health", "life", "car", "vehicle", "claim"
            ],
            TRANS_TAG_PERSONAL: [
                "salon", "haircut", "spa", "clothes", "clothing", "shopping", "shoes", "beauty",
                "cosmetics", "gym", "fitness", "barber", "grooming", "massage", "fashion"
            ],
            TRANS_TAG_SAVINGS: [
                "investment", "deposit", "stocks", "mutual", "fund", "savings", "shares", "crypto",
                "equity", "sip", "bonds", "zerodha", "groww"
            ],
            TRANS_TAG_OTHERS: [
                "gift", "donation", "fee", "miscellaneous", "tax", "charge", "charity", "tip"
            ]
        ]
    }
    
    // MARK: - Core Matching Engine
    
    /// Suggests top 1-2 categories for a user-typed title/description.
    func suggestCategories(for title: String, limit: Int = 2) -> [CategorySuggestion] {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        let tokens = extractTokens(from: trimmed)
        guard !tokens.isEmpty else { return [] }
        
        var scores: [String: Double] = [:]
        
        for (tagKey, keywords) in categoryKeywords {
            var maxCategoryScore = 0.0
            
            for token in tokens {
                for keyword in keywords {
                    let score = computeSimilarity(word: token, keyword: keyword)
                    if score > maxCategoryScore {
                        maxCategoryScore = score
                    }
                }
            }
            
            if maxCategoryScore >= 0.52 { // Reasonable similarity threshold cutoff
                scores[tagKey] = maxCategoryScore
            }
        }
        
        // Rank categories by highest score
        let sorted = scores.sorted { $0.value > $1.value }
        
        return sorted.prefix(limit).map { (tagKey, score) in
            CategorySuggestion(
                tagKey: tagKey,
                tagTitle: getTransTagTitle(transTag: tagKey),
                iconName: getTransTagIcon(transTag: tagKey),
                score: score
            )
        }
    }
    
    /// Computes similarity score in [0.0 ... 1.0] between a typed word and a keyword.
    private func computeSimilarity(word: String, keyword: String) -> Double {
        let w = word.lowercased()
        let k = keyword.lowercased()
        
        // Exact match or substring prefix match gets highest confidence
        if w == k { return 1.0 }
        if w.hasPrefix(k) || k.hasPrefix(w) {
            if min(w.count, k.count) >= 3 { return 0.90 }
        }
        
        // NaturalLanguage Word Embedding Cosine Distance (0.0 = identical, 2.0 = opposite)
        if let embedding = embedding {
            let distance = embedding.distance(between: w, and: k, distanceType: .cosine)
            if distance < 2.0 {
                // Convert distance to similarity score: similarity = 1.0 - (distance / 1.4)
                let similarity = max(0.0, 1.0 - (distance / 1.4))
                return similarity
            }
        }
        
        return 0.0
    }
    
    /// Extracts meaningful word tokens from description string, filtering stop words.
    private func extractTokens(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "a", "an", "the", "at", "in", "on", "for", "to", "from", "by", "with", "and", "or", "of",
            "is", "was", "my", "our", "your", "paid", "spent", "bought", "got", "item"
        ]
        
        let components = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components.filter { word in
            word.count >= 2 && !stopWords.contains(word)
        }
    }
    
    // MARK: - On-Device Learning
    
    /// Quietly learns new title word tokens when the user saves a transaction for a given category.
    func learnKeywords(from title: String, for tagKey: String) {
        let tokens = extractTokens(from: title)
        guard !tokens.isEmpty else { return }
        
        var currentList = categoryKeywords[tagKey] ?? defaultKeywords[tagKey] ?? []
        var updated = false
        
        for token in tokens {
            if !currentList.contains(token) {
                currentList.append(token)
                updated = true
            }
        }
        
        if updated {
            categoryKeywords[tagKey] = currentList
        }
    }
    
    // MARK: - Persistence
    
    private func persistKeywords() {
        if let data = try? JSONEncoder().encode(categoryKeywords) {
            UserDefaults.standard.set(data, forKey: UD_CATEGORY_KEYWORDS)
        }
    }
    
    private func loadKeywords() {
        if let data = UserDefaults.standard.data(forKey: UD_CATEGORY_KEYWORDS),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data),
           !decoded.isEmpty {
            self.categoryKeywords = decoded
        } else {
            self.categoryKeywords = defaultKeywords
        }
    }
}
