//
//  ExchangeRateService.swift
//  MoneyManager
//
//  Live exchange rates via api.frankfurter.app (free, no API key).
//  Caches rates in UserDefaults. Refreshes every 24 hours or on demand.
//  Falls back gracefully to cached rates when offline.
//

import Foundation
import Combine

@MainActor
class ExchangeRateService: ObservableObject {
    
    static let shared = ExchangeRateService()
    
    // MARK: - Published State
    
    /// Rates relative to the base currency. e.g. rates["EUR"] = 0.87 when base = "USD"
    @Published private(set) var rates: [String: Double] = [:]
    /// The base currency the current rates are quoted in.
    @Published private(set) var baseCurrency: String = "USD"
    /// When rates were last successfully fetched.
    @Published private(set) var lastUpdated: Date? = nil
    /// True when showing cached rates (offline or within 24h window).
    @Published private(set) var isUsingCachedRates: Bool = false
    /// Non-nil when a fetch error occurred AND no cache is available.
    @Published private(set) var fetchError: String? = nil
    
    // MARK: - Private
    
    private let cacheRatesKey    = UD_EXCHANGE_RATES_CACHE
    private let cacheTimestampKey = UD_EXCHANGE_RATES_TIMESTAMP
    private let cacheTTL: TimeInterval = 24 * 60 * 60  // 24 hours
    private var cancellable: AnyCancellable?
    
    private init() {
        loadFromCache()
        refreshIfStale()
    }
    
    // MARK: - Public API
    
    /// Convert `amount` from `fromCode` to `toCode` using cached rates.
    /// Returns the original amount unchanged if conversion is not possible
    /// (e.g. unsupported currency pair, no rates loaded).
    func convertedAmount(_ amount: Double, from fromCode: String, to toCode: String) -> Double {
        guard fromCode != toCode else { return amount }
        guard !rates.isEmpty else { return amount }
        
        // Convert via USD as the common base
        let amountInUSD: Double
        if fromCode == "USD" {
            amountInUSD = amount
        } else if let fromRate = rates[fromCode] {
            amountInUSD = amount / fromRate  // fromRate = USD→fromCode, so reverse
        } else {
            return amount  // no rate available, show original
        }
        
        if toCode == "USD" { return amountInUSD }
        guard let toRate = rates[toCode] else { return amount }
        return amountInUSD * toRate
    }
    
    /// Returns true if we have a rate for this currency code.
    func hasRate(for code: String) -> Bool {
        code == "USD" || rates[code] != nil
    }
    
    /// Trigger a manual refresh regardless of cache age.
    func refresh() {
        fetchRates()
    }
    
    /// Refresh only if cache is older than TTL.
    func refreshIfStale() {
        if let timestamp = lastUpdated, Date().timeIntervalSince(timestamp) < cacheTTL {
            isUsingCachedRates = true
            return
        }
        fetchRates()
    }
    
    // MARK: - Networking
    
    private func fetchRates() {
        // Frankfurter returns all rates relative to the base.
        // We fix base = USD so every conversion can go through USD.
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD") else { return }
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: FrankfurterResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    if self.rates.isEmpty {
                        self.fetchError = "Could not load exchange rates: \(error.localizedDescription)"
                    } else {
                        self.isUsingCachedRates = true
                        self.fetchError = nil
                    }
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                self.rates = response.rates
                // Add USD→USD identity
                self.rates["USD"] = 1.0
                self.baseCurrency = response.base
                self.lastUpdated = Date()
                self.isUsingCachedRates = false
                self.fetchError = nil
                self.saveToCache(rates: self.rates)
            })
    }
    
    // MARK: - Cache
    
    private func saveToCache(rates: [String: Double]) {
        if let data = try? JSONEncoder().encode(rates) {
            UserDefaults.standard.set(data, forKey: cacheRatesKey)
        }
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }
    
    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheRatesKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            self.rates = decoded
            self.rates["USD"] = 1.0
        }
        if let ts = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date {
            self.lastUpdated = ts
        }
    }
    
    // MARK: - Formatted last-updated string
    
    var lastUpdatedLabel: String {
        guard let date = lastUpdated else { return "Rates not loaded" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return "Rates: \(fmt.string(from: date))"
    }
}

// MARK: - Codable response

private struct FrankfurterResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}
