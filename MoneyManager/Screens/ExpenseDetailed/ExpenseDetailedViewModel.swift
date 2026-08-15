//
//  ExpenseDetailedViewModel.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import CoreData

@MainActor
class ExpenseDetailedViewModel: ObservableObject {
    
    @Published var expenseObj: ExpenseCD
    
    @Published var alertMsg = String()
    @Published var showAlert = false
    @Published var closePresenter = false
    
    init(expenseObj: ExpenseCD) {
        self.expenseObj = expenseObj
    }
    
    func deleteNote(managedObjectContext: NSManagedObjectContext) {
        let tag = expenseObj.tag ?? ""
        managedObjectContext.delete(expenseObj)
        do {
            try managedObjectContext.save()
            
            // Re-evaluate ActivityKit Live Activity for this category
            if #available(iOS 16.2, *) {
                let displayCurrency = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
                let symbol = currencySymbol(from: displayCurrency)
                let limit = BudgetManager.shared.limit(for: tag) ?? 0
                if limit > 0 {
                    let fetchRequest = NSFetchRequest<ExpenseCD>(entityName: "ExpenseCD")
                    let calendar = Calendar.current
                    let now = Date()
                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
                    
                    fetchRequest.predicate = NSPredicate(
                        format: "tag == %@ AND type == %@ AND occuredOn >= %@ AND occuredOn <= %@",
                        tag, TRANS_TYPE_EXPENSE, startOfMonth as NSDate, endOfMonth as NSDate
                    )
                    
                    if let items = try? managedObjectContext.fetch(fetchRequest) {
                        var totalSpent: Double = 0.0
                        for item in items {
                            let code = item.resolvedCurrencyCode
                            let converted = ExchangeRateService.shared.convertedAmount(item.amount, from: code, to: displayCurrency)
                            totalSpent += converted
                        }
                        
                        BudgetLiveActivityManager.shared.evaluateCategoryBudget(
                            tag: tag,
                            spent: totalSpent,
                            limit: limit,
                            currencySymbol: symbol
                        )
                    }
                }
            }
            
            closePresenter = true
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
    
    func shareNote() {
        let shareStr = """
        Title: \(expenseObj.title ?? "")
        Amount: \(currencySymbol(from: UserDefaults.standard.string(forKey: UD_EXPENSE_CURRENCY) ?? ""))\(expenseObj.amount)
        Transaction type: \(expenseObj.type == TRANS_TYPE_INCOME ? "Income" : "Expense")
        Category: \(getTransTagTitle(transTag: expenseObj.tag ?? ""))
        Date: \(getDateFormatter(date: expenseObj.occuredOn, format: "EEEE, dd MMM hh:mm a"))
        Note: \(expenseObj.note ?? "")
        
        \(SHARED_FROM_TRACKMINT)
        """
        let av = UIActivityViewController(activityItems: [shareStr], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
    }
}
