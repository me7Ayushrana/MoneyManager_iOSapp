//
//  BudgetLiveActivityAttributes.swift
//  MoneyManager
//
//  Created for TrackMint.
//  ActivityAttributes model for ActivityKit budget Live Activity & Dynamic Island.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BudgetLiveActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var categoryTag: String
        var categoryName: String
        var categoryIcon: String
        var spentAmount: Double
        var budgetLimit: Double
        var currencySymbol: String
        var progressFraction: Double // e.g. 0.75, 0.95, 1.10
        var isExceeded: Bool
        var percentageInt: Int
    }
    
    // Non-changing static context
    var categoryId: String
}
