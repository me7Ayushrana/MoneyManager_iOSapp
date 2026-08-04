//
//  BudgetManager.swift
//  MoneyManager
//
//  Stores monthly budget limits per expense category in UserDefaults.
//  All limits are stored in the user's chosen Display Currency.
//

import Foundation
import Combine

enum BudgetStatus {
    case none       // no budget set
    case ok         // < 70%
    case warning    // 70–100%
    case exceeded   // > 100%
    
    var color: String {
        switch self {
        case .none:     return "9CA3AF"  // grey
        case .ok:       return "10B981"  // green
        case .warning:  return "F59E0B"  // amber
        case .exceeded: return "EF4444"  // red
        }
    }
}

struct BudgetProgress {
    let limit: Double        // monthly budget limit in display currency
    let spent: Double        // amount spent this month (converted)
    let fraction: Double     // clamps to 0...1+ for progress bar
    let status: BudgetStatus
    
    var percentageText: String {
        guard limit > 0 else { return "" }
        return "\(Int(min((spent / limit) * 100, 999)))%"
    }
    
    var limitText: String { String(format: "%.2f", limit) }
    var spentText: String { String(format: "%.2f", spent) }
}

@MainActor
class BudgetManager: ObservableObject {
    
    static let shared = BudgetManager()
    
    /// [tagKey: monthlyLimit in Display Currency]
    @Published private(set) var limits: [String: Double] = [:] {
        didSet { persist() }
    }
    
    private let key = UD_BUDGET_LIMITS
    
    private init() { load() }
    
    // MARK: - Public API
    
    func setLimit(_ amount: Double, for tag: String) {
        if amount <= 0 {
            limits.removeValue(forKey: tag)
        } else {
            limits[tag] = amount
        }
    }
    
    func limit(for tag: String) -> Double? { limits[tag] }
    
    /// Converts all category limits when the user changes Display Currency.
    func convertLimits(from oldCode: String, to newCode: String, using exchangeService: ExchangeRateService) {
        guard oldCode != newCode else { return }
        var updated = [String: Double]()
        for (tag, val) in limits {
            let converted = exchangeService.convertedAmount(val, from: oldCode, to: newCode)
            updated[tag] = converted
        }
        limits = updated
    }
    
    /// Compute budget progress for a category given the total converted spend this month.
    func progress(for tag: String, spent: Double) -> BudgetProgress {
        guard let limit = limits[tag], limit > 0 else {
            return BudgetProgress(limit: 0, spent: spent, fraction: 0, status: .none)
        }
        let fraction = spent / limit
        let status: BudgetStatus
        switch fraction {
        case ..<0.70: status = .ok
        case 0.70..<1.0: status = .warning
        default: status = .exceeded
        }
        return BudgetProgress(limit: limit, spent: spent, fraction: fraction, status: status)
    }
    
    // MARK: - Persistence
    
    private func persist() {
        if let data = try? JSONEncoder().encode(limits) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else { return }
        limits = decoded
    }
}
