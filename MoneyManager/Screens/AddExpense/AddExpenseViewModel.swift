//
//  AddExpenseViewModel.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import CoreData

class AddExpenseViewModel: ObservableObject {
    
    var expenseObj: ExpenseCD?
    
    @Published var title = ""
    @Published var amount = ""
    @Published var occuredOn = Date()
    @Published var note = ""
    @Published var typeTitle = "Income"
    @Published var tagTitle = getTransTagTitle(transTag: TRANS_TAG_TRANSPORT)
    @Published var showTypeDrop = false
    @Published var showTagDrop = false
    
    @Published var selectedType = TRANS_TYPE_INCOME
    @Published var selectedTag = TRANS_TAG_TRANSPORT
    
    /// ISO currency code for this transaction — defaults to user's Display Currency
    @Published var selectedCurrencyCode: String = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
    @Published var showCurrencyPicker = false
    @Published var showCalculator = false
    
    @Published var imageUpdated = false
    @Published var imageAttached: UIImage? = nil
    
    @Published var alertMsg = String()
    @Published var showAlert = false
    @Published var closePresenter = false
    
    init(expenseObj: ExpenseCD? = nil) {
        self.expenseObj = expenseObj
        self.title = expenseObj?.title ?? ""
        if let expenseObj = expenseObj {
            let amt = expenseObj.amount
            self.amount = amt.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amt) : String(format: "%.2f", amt)
            self.typeTitle = expenseObj.type == TRANS_TYPE_INCOME ? "Income" : "Expense"
            self.selectedCurrencyCode = expenseObj.resolvedCurrencyCode
        } else {
            self.amount = ""
            self.typeTitle = "Income"
            self.selectedCurrencyCode = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
        }
        self.occuredOn = expenseObj?.occuredOn ?? Date()
        self.note = expenseObj?.note ?? ""
        self.tagTitle = getTransTagTitle(transTag: expenseObj?.tag ?? TRANS_TAG_TRANSPORT)
        self.selectedType = expenseObj?.type ?? TRANS_TYPE_INCOME
        self.selectedTag = expenseObj?.tag ?? TRANS_TAG_TRANSPORT
        if let data = expenseObj?.imageAttached {
            self.imageAttached = UIImage(data: data)
        }
        
        AttachmentHandler.shared.imagePickedBlock = { [weak self] image in
            self?.imageUpdated = true
            self?.imageAttached = image
        }
    }
    
    func getButtText() -> String {
        if selectedType == TRANS_TYPE_INCOME { return "\(expenseObj == nil ? "ADD" : "EDIT") INCOME" }
        else if selectedType == TRANS_TYPE_EXPENSE { return "\(expenseObj == nil ? "ADD" : "EDIT") EXPENSE" }
        else { return "\(expenseObj == nil ? "ADD" : "EDIT") TRANSACTION" }
    }
    
    /// Short display label for the currently selected currency, e.g. "₹ INR"
    var currencyDisplayLabel: String {
        supportedCurrency(for: selectedCurrencyCode)?.shortLabel ?? selectedCurrencyCode
    }
    
    func attachImage() { AttachmentHandler.shared.showAttachmentActionSheet() }
    
    func removeImage() { imageAttached = nil }
    
    /// Evaluates any arithmetic expression in `amount` string e.g. "100+25-10" → 115.0
    func parseAmountValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Double(trimmed) { return direct }
        
        var sanitized = trimmed.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
        while let last = sanitized.last, ["+", "-", "*", "/"].contains(String(last)) {
            sanitized.removeLast()
        }
        guard !sanitized.isEmpty else { return nil }
        
        let expression = NSExpression(format: sanitized)
        if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            return result.doubleValue
        }
        return nil
    }
    
    func saveTransaction(managedObjectContext: NSManagedObjectContext) {
        
        let expense: ExpenseCD
        let titleStr = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountStr = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if titleStr.isEmpty { alertMsg = "Enter Title"; showAlert = true; return }
        if amountStr.isEmpty { alertMsg = "Enter Amount"; showAlert = true; return }
        
        guard let amountVal = parseAmountValue(amountStr) else {
            alertMsg = "Enter a valid number or math expression (e.g. 50+20)"; showAlert = true; return
        }
        guard amountVal >= 0 else {
            alertMsg = "Amount can't be negative"; showAlert = true; return
        }
        guard amountVal <= 1_000_000_000 else {
            alertMsg = "Enter a smaller amount"; showAlert = true; return
        }
        
        // Update amount field with evaluated number
        self.amount = amountVal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amountVal) : String(format: "%.2f", amountVal)
        
        if expenseObj != nil {
            expense = expenseObj!
            if let image = imageAttached {
                if imageUpdated {
                    expense.imageAttached = image.jpegData(compressionQuality: 1.0)
                }
            } else {
                expense.imageAttached = nil
            }
        } else {
            expense = ExpenseCD(context: managedObjectContext)
            expense.createdAt = Date()
            if let image = imageAttached {
                expense.imageAttached = image.jpegData(compressionQuality: 1.0)
            }
        }
        expense.updatedAt = Date()
        expense.type = selectedType
        expense.title = titleStr
        expense.tag = selectedTag
        expense.occuredOn = occuredOn
        expense.note = note
        expense.amount = amountVal
        expense.currencyCode = selectedCurrencyCode
        do {
            try managedObjectContext.save()
            closePresenter = true
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
    
    func deleteTransaction(managedObjectContext: NSManagedObjectContext) {
        guard let expenseObj = expenseObj else { return }
        managedObjectContext.delete(expenseObj)
        do {
            try managedObjectContext.save(); closePresenter = true
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
}
