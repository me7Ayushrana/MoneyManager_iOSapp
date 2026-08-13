//
//  BudgetLiveActivityManager.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Manages starting, updating, and ending ActivityKit Live Activities for budget categories crossing 70% threshold.
//

import ActivityKit
import Foundation
import UIKit

@available(iOS 16.2, *)
@MainActor
class BudgetLiveActivityManager {
    
    static let shared = BudgetLiveActivityManager()
    
    private init() {}
    
    /// Evaluates category budget progress and starts/updates/ends Live Activity if spending crosses 70% threshold.
    func evaluateCategoryBudget(tag: String, spent: Double, limit: Double, currencySymbol: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let fraction = limit > 0 ? spent / limit : 0.0
        let percent = Int(min(fraction * 100, 999))
        
        let existingActivity = Activity<BudgetLiveActivityAttributes>.activities.first {
            $0.attributes.categoryId == tag
        }
        
        if fraction >= 0.70 {
            // Category has crossed 70% threshold!
            let categoryName = getTransTagTitle(transTag: tag)
            let categoryIcon = getCategoryIconName(tag: tag)
            let isExceeded = fraction >= 1.0
            
            let newState = BudgetLiveActivityAttributes.ContentState(
                categoryTag: tag,
                categoryName: categoryName,
                categoryIcon: categoryIcon,
                spentAmount: spent,
                budgetLimit: limit,
                currencySymbol: currencySymbol,
                progressFraction: min(fraction, 1.5),
                isExceeded: isExceeded,
                percentageInt: percent
            )
            
            if let activity = existingActivity {
                // Update existing Live Activity in real-time
                Task {
                    let content = ActivityContent(state: newState, staleDate: nil)
                    await activity.update(content)
                }
            } else {
                // Start a new Live Activity
                let attributes = BudgetLiveActivityAttributes(categoryId: tag)
                let content = ActivityContent(state: newState, staleDate: nil)
                do {
                    _ = try Activity.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                } catch {
                    print("⚠️ Failed to start Live Activity for \(tag): \(error.localizedDescription)")
                }
            }
        } else {
            // Spending is under 70%, end activity if it exists
            if let activity = existingActivity {
                Task {
                    let finalState = activity.content.state
                    let finalContent = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(finalContent, dismissalPolicy: .immediate)
                }
            }
        }
    }
    
    /// Ends all active Live Activities (e.g., month reset or sign out).
    func endAllActivities() {
        for activity in Activity<BudgetLiveActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    private func getCategoryIconName(tag: String) -> String {
        switch tag {
        case TRANS_TAG_FOOD:          return "cart.fill"
        case TRANS_TAG_TRANSPORT:     return "car.fill"
        case TRANS_TAG_HOUSING:       return "house.fill"
        case TRANS_TAG_UTILITIES:     return "bolt.fill"
        case TRANS_TAG_ENTERTAINMENT: return "film.fill"
        case TRANS_TAG_MEDICAL:       return "cross.case.fill"
        case TRANS_TAG_INSURANCE:     return "shield.fill"
        case TRANS_TAG_PERSONAL:      return "person.fill"
        case TRANS_TAG_SAVINGS:       return "banknote.fill"
        default:                      return "tag.fill"
        }
    }
}
