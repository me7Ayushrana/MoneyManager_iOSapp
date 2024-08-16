//
//  ExpenseSettingsViewModel.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import Combine
import CoreData
import LocalAuthentication

@MainActor
class ExpenseSettingsViewModel: ObservableObject {
    
    var csvModelArr = [ExpenseCSVModel]()
    var cancellableBiometricTask: AnyCancellable? = nil
    
    @Published var displayCurrency = UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) ?? "INR"
    @Published var enableBiometric = UserDefaults.standard.bool(forKey: UD_USE_BIOMETRIC) {
        didSet {
            if enableBiometric { authenticate() }
            else { UserDefaults.standard.setValue(false, forKey: UD_USE_BIOMETRIC) }
        }
    }
    
    @Published var alertMsg = String()
    @Published var showAlert = false
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    init() {}
        
    func authenticate() {
        showAlert = false
        alertMsg = ""
        cancellableBiometricTask = BiometricAuthUtlity.shared.authenticate()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    self.showAlert = true
                    self.alertMsg = error.description
                    self.enableBiometric = false
                default: return
                }
            }) { _ in
                UserDefaults.standard.setValue(true, forKey: UD_USE_BIOMETRIC)
            }
    }
    
    func getBiometricType() -> String {
        if #available(iOS 11.0, *) {
            let context = LAContext()
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                switch context.biometryType {
                    case .faceID: return "Face ID"
                    case .touchID: return "Touch ID"
                    case .none: return "App Lock"
                    @unknown default: return "App Lock"
                }
            }
        }
        return "App Lock"
    }
    
    func saveDisplayCurrency(code: String, exchangeService: ExchangeRateService) {
        let oldCode = self.displayCurrency
        guard oldCode != code else { return }
        
        let currentBudget = UserDefaults.standard.double(forKey: UD_MONTHLY_BUDGET)
        let effectiveBudget = currentBudget > 0 ? currentBudget : 5000.0
        let convertedBudget = exchangeService.convertedAmount(effectiveBudget, from: oldCode, to: code)
        UserDefaults.standard.set(convertedBudget, forKey: UD_MONTHLY_BUDGET)
        
        BudgetManager.shared.convertLimits(from: oldCode, to: code, using: exchangeService)
        
        self.displayCurrency = code
        UserDefaults.standard.set(code, forKey: UD_DISPLAY_CURRENCY)
    }
    
    func exportTransactions(moc: NSManagedObjectContext, exchangeService: ExchangeRateService) {
        let request = ExpenseCD.fetchRequest()
        var results: [ExpenseCD]
        do {
            results = try moc.fetch(request) as! [ExpenseCD]
            if results.count <= 0 { alertMsg = "No data to export"; showAlert = true }
            else {
                csvModelArr.removeAll()
                for i in results {
                    let csvModel = ExpenseCSVModel()
                    csvModel.title = i.title ?? ""
                    let originalCode = i.resolvedCurrencyCode
                    let converted = exchangeService.convertedAmount(i.amount, from: originalCode, to: displayCurrency)
                    csvModel.amount = "\(symbolFor(currencyCode: displayCurrency))\(String(format: "%.2f", converted)) (\(symbolFor(currencyCode: originalCode))\(i.amount) \(originalCode))"
                    csvModel.transactionType = "\(i.type == TRANS_TYPE_INCOME ? "INCOME" : "EXPENSE")"
                    csvModel.tag = getTransTagTitle(transTag: i.tag ?? "")
                    csvModel.occuredOn = "\(getDateFormatter(date: i.occuredOn, format: "yyyy-MM-dd hh:mm a"))"
                    csvModel.note = i.note ?? ""
                    csvModelArr.append(csvModel)
                }
                self.generateCSV()
            }
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
    
    func generateCSV() {
        let fileName = "Expense.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        var csvText = "Title,Amount (Converted & Original),Type,Tag,Occured On,Note\n"
        
        for csvModel in csvModelArr {
            let row = "\"\(csvModel.title)\",\"\(csvModel.amount)\",\"\(csvModel.transactionType)\",\"\(csvModel.tag)\",\"\(csvModel.occuredOn)\",\"\(csvModel.note)\"\n"
            csvText.append(row)
        }
        
        do {
            try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
            let av = UIActivityViewController(activityItems: [path!], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
        } catch { alertMsg = "\(error)"; showAlert = true }
    }
    
    deinit {
        cancellableBiometricTask = nil
    }
}
