//
//  BudgetLiveActivityView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Widget ActivityConfiguration rendering Dynamic Island (Compact, Minimal, Expanded) and Lock Screen banners.
//

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct BudgetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetLiveActivityAttributes.self) { context in
            // Lock Screen Banner UI
            LockScreenBudgetCard(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island UI (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.categoryIcon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(statusColor(for: context.state.progressFraction))
                        Text(context.state.categoryName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.percentageInt)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(statusColor(for: context.state.progressFraction))
                        .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Spent: \(context.state.currencySymbol)\(String(format: "%.2f", context.state.spentAmount))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text("Limit: \(context.state.currencySymbol)\(String(format: "%.2f", context.state.budgetLimit))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Progress Bar (Green <90%, Amber 90-100%, Red >100%)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(statusColor(for: context.state.progressFraction))
                                    .frame(width: geo.size.width * CGFloat(min(context.state.progressFraction, 1.0)))
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                // Compact Leading Dynamic Island UI
                Image(systemName: context.state.categoryIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor(for: context.state.progressFraction))
            } compactTrailing: {
                // Compact Trailing Dynamic Island UI
                Text("\(context.state.percentageInt)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor(for: context.state.progressFraction))
            } minimal: {
                // Minimal Dynamic Island UI
                Image(systemName: context.state.categoryIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor(for: context.state.progressFraction))
            }
        }
    }
}

// Lock Screen Card View Component
@available(iOS 16.1, *)
struct LockScreenBudgetCard: View {
    let state: BudgetLiveActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: state.categoryIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(statusColor(for: state.progressFraction))
                    Text(state.categoryName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(state.isExceeded ? "Exceeded 🚨" : "Warning ⚠️")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(state.percentageInt)%")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(statusColor(for: state.progressFraction))
            }
            
            HStack {
                Text("\(state.currencySymbol)\(String(format: "%.2f", state.spentAmount)) spent")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("of \(state.currencySymbol)\(String(format: "%.2f", state.budgetLimit)) limit")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusColor(for: state.progressFraction))
                        .frame(width: geo.size.width * CGFloat(min(state.progressFraction, 1.0)))
                }
            }
            .frame(height: 8)
        }
        .padding(16)
    }
}

private func statusColor(for fraction: Double) -> Color {
    switch fraction {
    case ..<0.90: return Color(red: 16/255, green: 185/255, blue: 129/255)  // Green
    case 0.90..<1.0: return Color(red: 245/255, green: 158/255, blue: 11/255) // Amber
    default: return Color(red: 239/255, green: 68/255, blue: 68/255)          // Red
    }
}
