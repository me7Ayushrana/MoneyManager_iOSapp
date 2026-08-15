//
//  AddExpenseViewModel.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import Combine
import CoreData
import SwiftUI

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
    
    /// Smart category suggestions powered by NLEmbedding
    @Published var suggestedCategories: [CategorySuggestion] = []
    private var cancellableTitle: AnyCancellable?
    
    /// Voice dictation service & transcript
    @ObservedObject var speechRecognizer = SpeechRecognizerService()
    @Published var voiceTranscript: String = ""
    @Published var showVoicePermissionAlert = false
    
    /// Receipt Scanner properties
    @Published var isReceiptScannedBanner = false
    @Published var showReceiptOptions = false
    @Published var showLiveScanner = false
    @Published var showReceiptPhotoPicker = false
    
    /// ISO currency code for this transaction — defaults to user's Display Currency
    @Published var selectedCurrencyCode: String = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
    @Published var showCurrencyPicker = false
    @Published var showCalculator = false
    
    @Published var imageUpdated = false
    @Published var imageAttached: UIImage? = nil
    
    @Published var alertMsg = String()
    @Published var showAlert = false
    @Published var closePresenter = false
    
    func processReceiptImage(_ image: UIImage) {
        self.imageAttached = image
        self.imageUpdated = true
        
        ReceiptScannerService.shared.processReceiptImage(image) { [weak self] parsed in
            guard let self = self else { return }
            
            if let merchant = parsed.merchantName {
                self.title = merchant
            }
            
            if let amt = parsed.totalAmount {
                self.amount = amt.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amt) : String(format: "%.2f", amt)
            } else {
                self.amount = ""
            }
            
            if let dt = parsed.date {
                self.occuredOn = dt
            }
            
            if let tagKey = parsed.suggestedTagKey {
                self.selectedTag = tagKey
                self.tagTitle = getTransTagTitle(transTag: tagKey)
            }
            
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                self.isReceiptScannedBanner = true
            }
        }
    }
    
    func toggleVoiceDictation() {
        if speechRecognizer.permissionDenied {
            showVoicePermissionAlert = true
            return
        }
        
        speechRecognizer.toggleRecording { [weak self] partialText in
            self?.voiceTranscript = partialText
        } onCompletion: { [weak self] finalTranscript in
            guard let self = self, !finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            self.applyVoiceTranscript(finalTranscript)
        }
    }
    
    func applyVoiceTranscript(_ rawText: String) {
        let parsed = VoiceExpenseParser.shared.parse(rawText, defaultCurrency: selectedCurrencyCode)
        
        self.title = parsed.title
        
        if let amt = parsed.amount {
            self.amount = amt.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", amt) : String(format: "%.2f", amt)
        }
        
        if let curr = parsed.currencyCode {
            self.selectedCurrencyCode = curr
        }
        
        self.occuredOn = parsed.date
        
        if let tagKey = parsed.suggestedTagKey {
            self.selectedTag = tagKey
            self.tagTitle = getTransTagTitle(transTag: tagKey)
        }
        
        self.selectedType = parsed.transactionType
        self.typeTitle = parsed.transactionType == TRANS_TYPE_INCOME ? "Income" : "Expense"
    }
    
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
            self.typeTitle = "Expense"
            self.selectedCurrencyCode = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
        }
        self.occuredOn = expenseObj?.occuredOn ?? Date()
        self.note = expenseObj?.note ?? ""
        self.tagTitle = getTransTagTitle(transTag: expenseObj?.tag ?? TRANS_TAG_TRANSPORT)
        self.selectedType = expenseObj?.type ?? TRANS_TYPE_EXPENSE
        self.selectedTag = expenseObj?.tag ?? TRANS_TAG_TRANSPORT
        if let data = expenseObj?.imageAttached {
            self.imageAttached = UIImage(data: data)
        }
        
        // Debounce title typing by 300ms for smart category suggestions
        cancellableTitle = $title
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                let suggestions = SmartCategoryManager.shared.suggestCategories(for: text)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    self.suggestedCategories = suggestions
                }
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
        
        // On-device learning: learn title word tokens for selected category
        SmartCategoryManager.shared.learnKeywords(from: titleStr, for: selectedTag)
        
        do {
            try managedObjectContext.save()
            
            // Evaluate ActivityKit Live Activity for budget category
            if #available(iOS 16.2, *) {
                let displayCurrency = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
                let symbol = currencySymbol(from: displayCurrency)
                let limit = BudgetManager.shared.limit(for: selectedTag) ?? 0
                if limit > 0 {
                    let fetchRequest = NSFetchRequest<ExpenseCD>(entityName: "ExpenseCD")
                    let calendar = Calendar.current
                    let now = Date()
                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
                    
                    fetchRequest.predicate = NSPredicate(
                        format: "tag == %@ AND type == %@ AND occuredOn >= %@ AND occuredOn <= %@",
                        selectedTag, TRANS_TYPE_EXPENSE, startOfMonth as NSDate, endOfMonth as NSDate
                    )
                    
                    if let items = try? managedObjectContext.fetch(fetchRequest) {
                        var totalSpent: Double = 0.0
                        for item in items {
                            let code = item.resolvedCurrencyCode
                            let converted = ExchangeRateService.shared.convertedAmount(item.amount, from: code, to: displayCurrency)
                            totalSpent += converted
                        }
                        
                        BudgetLiveActivityManager.shared.evaluateCategoryBudget(
                            tag: selectedTag,
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
    
    func deleteTransaction(managedObjectContext: NSManagedObjectContext) {
        guard let expenseObj = expenseObj else { return }
        let tag = expenseObj.tag ?? selectedTag
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
}
