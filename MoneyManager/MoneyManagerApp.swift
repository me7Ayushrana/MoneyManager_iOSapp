//
//  MoneyManagerApp.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import CoreData

@main
struct MoneyManagerApp: App {
    
    @StateObject private var themeManager      = ThemeManager()
    @StateObject private var exchangeService   = ExchangeRateService.shared
    @StateObject private var budgetManager     = BudgetManager.shared
    
    init() {
        self.setDefaultPreferences()
    }
    
    private func setDefaultPreferences() {
        // Set Display Currency from device locale on first launch
        if UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) == nil {
            let localeCode = Locale.current.currencyCode ?? "INR"
            let finalCode = SUPPORTED_CURRENCIES.contains(where: { $0.code == localeCode }) ? localeCode : "INR"
            UserDefaults.standard.set(finalCode, forKey: UD_DISPLAY_CURRENCY)
        }
        // Legacy: if old UD_EXPENSE_CURRENCY is set but UD_DISPLAY_CURRENCY isn't, migrate it
        if let legacy = UserDefaults.standard.string(forKey: UD_EXPENSE_CURRENCY),
           !legacy.isEmpty {
            if UserDefaults.standard.string(forKey: UD_DISPLAY_CURRENCY) == nil {
                let code = isoCode(fromLegacyEntry: legacy)
                UserDefaults.standard.set(code, forKey: UD_DISPLAY_CURRENCY)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if UserDefaults.standard.bool(forKey: UD_USE_BIOMETRIC) {
                    AuthenticateView(viewModel: AuthenticationViewModel())
                        .environment(\.managedObjectContext, persistentContainer.viewContext)
                } else {
                    ExpenseView()
                        .environment(\.managedObjectContext, persistentContainer.viewContext)
                }
            }
            .environmentObject(themeManager)
            .environmentObject(exchangeService)
            .environmentObject(budgetManager)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MoneyManager")
        // Enable lightweight automatic migration so v1→v2 (adding currencyCode) is seamless
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("⚠️ CoreData load error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
}
