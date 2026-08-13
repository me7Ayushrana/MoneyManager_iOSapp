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
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            UserDefaults.standard.set(true, forKey: "isDarkMode")
        }
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
    
    @StateObject private var authManager       = AppleAuthManager.shared
    @StateObject private var syncMonitor       = CloudKitSyncMonitor.shared
    
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
            .environmentObject(authManager)
            .environmentObject(syncMonitor)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
    
    var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "MoneyManager")
        let storeDescription = container.persistentStoreDescriptions.first
        
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("⚠️ CoreData/CloudKit load error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
}
