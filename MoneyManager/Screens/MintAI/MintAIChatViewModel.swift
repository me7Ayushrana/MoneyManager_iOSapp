//
//  MintAIChatViewModel.swift
//  MoneyManager
//
//  Created for TrackMint.
//  ViewModel for MintAI assistant fetching Core Data financial metrics and querying Gemini AI.
//

import SwiftUI
import CoreData

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let date: Date
}

@MainActor
class MintAIChatViewModel: ObservableObject {
    
    @Published var messages: [ChatMessage] = []
    @Published var userInput: String = ""
    @Published var isLoading: Bool = false
    @Published var showKeySetup: Bool = false
    @Published var alertMessage: String? = nil
    
    @AppStorage(UD_USER_CUSTOM_NAME) var customUserName: String = "Ayush"
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    
    init() {
        // Welcome message
        let welcome = ChatMessage(
            text: "Hello! I'm **MintAI**, your personal financial assistant. Ask me anything about your spending, budget advice, or savings tips based on your TrackMint records!",
            isUser: false,
            date: Date()
        )
        self.messages.append(welcome)
    }
    
    func sendQuickQuery(_ query: String, moc: NSManagedObjectContext, exchangeService: ExchangeRateService) {
        self.userInput = query
        sendMessage(moc: moc, exchangeService: exchangeService)
    }
    
    func sendMessage(moc: NSManagedObjectContext, exchangeService: ExchangeRateService) {
        let trimmedQuery = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        if !GeminiAIService.shared.isKeyConfigured {
            self.showKeySetup = true
            return
        }
        
        // Append User Message
        let userMsg = ChatMessage(text: trimmedQuery, isUser: true, date: Date())
        self.messages.append(userMsg)
        self.userInput = ""
        self.isLoading = true
        
        // Build Financial Context from Core Data
        let contextSummary = buildFinancialContext(moc: moc, exchangeService: exchangeService)
        
        GeminiAIService.shared.askMintAI(userQuery: trimmedQuery, financialContext: contextSummary, userName: customUserName) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let aiResponse):
                let aiMsg = ChatMessage(text: aiResponse, isUser: false, date: Date())
                self.messages.append(aiMsg)
            case .failure(let error):
                let errMsg = ChatMessage(text: "⚠️ \(error.localizedDescription)", isUser: false, date: Date())
                self.messages.append(errMsg)
            }
        }
    }
    
    private func buildFinancialContext(moc: NSManagedObjectContext, exchangeService: ExchangeRateService) -> String {
        let request = NSFetchRequest<ExpenseCD>(entityName: "ExpenseCD")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseCD.occuredOn, ascending: false)]
        
        guard let allTransactions = try? moc.fetch(request) else {
            return "No transactions recorded yet."
        }
        
        var totalIncome: Double = 0
        var totalExpense: Double = 0
        var categoryTotals: [String: Double] = [:]
        
        let cal = Calendar.current
        let currentMonth = cal.component(.month, from: Date())
        let currentYear = cal.component(.year, from: Date())
        
        var monthlyIncome: Double = 0
        var monthlyExpense: Double = 0
        
        var recentLines: [String] = []
        
        for (idx, tx) in allTransactions.enumerated() {
            let amountInDisplayCurrency = exchangeService.convertedAmount(tx.amount, from: tx.resolvedCurrencyCode, to: displayCurrency)
            
            if tx.type == TRANS_TYPE_INCOME {
                totalIncome += amountInDisplayCurrency
            } else {
                totalExpense += amountInDisplayCurrency
                let tagKey = tx.tag ?? TRANS_TAG_OTHERS
                categoryTotals[tagKey, default: 0] += amountInDisplayCurrency
            }
            
            if let date = tx.occuredOn {
                let txMonth = cal.component(.month, from: date)
                let txYear = cal.component(.year, from: date)
                if txMonth == currentMonth && txYear == currentYear {
                    if tx.type == TRANS_TYPE_INCOME {
                        monthlyIncome += amountInDisplayCurrency
                    } else {
                        monthlyExpense += amountInDisplayCurrency
                    }
                }
            }
            
            if idx < 15 {
                let dateStr = tx.occuredOn != nil ? DateFormatter.localizedString(from: tx.occuredOn!, dateStyle: .short, timeStyle: .none) : "Recent"
                let title = tx.title ?? "Transaction"
                let type = tx.type?.capitalized ?? "Expense"
                recentLines.append("- \(dateStr): \(title) | \(type) | \(displayCurrency) \(String(format: "%.2f", amountInDisplayCurrency))")
            }
        }
        
        let netBalance = totalIncome - totalExpense
        let overallMonthlyBudget = UserDefaults.standard.double(forKey: UD_MONTHLY_BUDGET)
        
        var summary = """
        User Display Currency: \(displayCurrency)
        Overall Monthly Budget Target: \(displayCurrency) \(String(format: "%.2f", overallMonthlyBudget > 0 ? overallMonthlyBudget : 5000.0))
        
        All-Time Financial Metrics:
        - Total Lifetime Income: \(displayCurrency) \(String(format: "%.2f", totalIncome))
        - Total Lifetime Expenses: \(displayCurrency) \(String(format: "%.2f", totalExpense))
        - Net Balance: \(displayCurrency) \(String(format: "%.2f", netBalance))
        
        Current Month Summary:
        - Income This Month: \(displayCurrency) \(String(format: "%.2f", monthlyIncome))
        - Expenses This Month: \(displayCurrency) \(String(format: "%.2f", monthlyExpense))
        
        Expense Breakdown By Category:
        """
        
        for (catKey, amt) in categoryTotals.sorted(by: { $0.value > $1.value }) {
            summary += "\n- \(catKey.capitalized): \(displayCurrency) \(String(format: "%.2f", amt))"
        }
        
        summary += "\n\nRecent 15 Transactions:\n" + recentLines.joined(separator: "\n")
        
        return summary
    }
}
