//
//  Configs.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import Foundation

// App Globals
let APP_NAME = "TrackMint"
let APP_LINK = "https://github.com/me7Ayushrana/MoneyManager_iOSapp"
let SHARED_FROM_TRACKMINT = """
    Shared from \(APP_NAME) App: \(APP_LINK)
    """

// IMAGE_ICON NAMES
let IMAGE_DELETE_ICON = "delete_icon"
let IMAGE_SHARE_ICON = "share_icon"
let IMAGE_FILTER_ICON = "filter_icon"
let IMAGE_OPTION_ICON = "settings_icon"

// User Defaults Keys
let UD_USE_BIOMETRIC        = "useBiometric"
let UD_EXPENSE_CURRENCY     = "expenseCurrency"   // legacy symbol key — kept for backward compat
let UD_DISPLAY_CURRENCY     = "displayCurrencyCode" // ISO code for the user's chosen display currency
let UD_EXCHANGE_RATES_CACHE = "exchangeRatesCache"
let UD_EXCHANGE_RATES_TIMESTAMP = "exchangeRatesTimestamp"
let UD_BUDGET_LIMITS        = "budgetLimitsV1"    // [tagKey: monthlyLimit Double]
let UD_MONTHLY_BUDGET       = "overallMonthlyBudget" // Overall monthly budget Double
let UD_EXISTING_TX_MIGRATED = "existingTxCurrencyMigrated" // one-time migration flag
let UD_CATEGORY_KEYWORDS    = "categoryKeywordsV1" // [tagKey: [String]] custom keyword mapping
let UD_USER_CUSTOM_NAME     = "userCustomName"     // Custom name user wants to be called as
let KEYCHAIN_GEMINI_KEY     = "gemini_api_key"     // Google Gemini AI API key stored securely in Keychain

// Transaction types
let TRANS_TYPE_INCOME  = "income"
let TRANS_TYPE_EXPENSE = "expense"

// Transaction tags
let TRANS_TAG_TRANSPORT     = "transport"
let TRANS_TAG_FOOD          = "food"
let TRANS_TAG_HOUSING       = "housing"
let TRANS_TAG_INSURANCE     = "insurance"
let TRANS_TAG_MEDICAL       = "medical"
let TRANS_TAG_SAVINGS       = "savings"
let TRANS_TAG_PERSONAL      = "personal"
let TRANS_TAG_ENTERTAINMENT = "entertainment"
let TRANS_TAG_OTHERS        = "others"
let TRANS_TAG_UTILITIES     = "utilities"

// Supported Currencies — (code, symbol, name)
struct SupportedCurrency: Identifiable {
    let code: String     // ISO 4217
    let symbol: String   // display symbol
    let name: String
    var id: String { code }
    
    /// Display string shown in pickers, e.g. "₹ INR — Indian Rupee"
    var displayLabel: String { "\(symbol) \(code) — \(name)" }
    
    /// Short picker label e.g. "₹ INR"
    var shortLabel: String { "\(symbol) \(code)" }
}

let SUPPORTED_CURRENCIES: [SupportedCurrency] = [
    SupportedCurrency(code: "INR", symbol: "₹",    name: "Indian Rupee"),
    SupportedCurrency(code: "USD", symbol: "$",    name: "US Dollar"),
    SupportedCurrency(code: "EUR", symbol: "€",    name: "Euro"),
    SupportedCurrency(code: "GBP", symbol: "£",    name: "British Pound"),
    SupportedCurrency(code: "JPY", symbol: "¥",    name: "Japanese Yen"),
    SupportedCurrency(code: "AUD", symbol: "$",    name: "Australian Dollar"),
    SupportedCurrency(code: "CAD", symbol: "$",    name: "Canadian Dollar"),
    SupportedCurrency(code: "CHF", symbol: "Fr",   name: "Swiss Franc"),
    SupportedCurrency(code: "CNY", symbol: "¥",    name: "Chinese Yuan"),
    SupportedCurrency(code: "SGD", symbol: "$",    name: "Singapore Dollar"),
    SupportedCurrency(code: "AED", symbol: "د.إ",  name: "UAE Dirham"),
    SupportedCurrency(code: "SAR", symbol: "﷼",    name: "Saudi Riyal"),
    SupportedCurrency(code: "KRW", symbol: "₩",    name: "South Korean Won"),
    SupportedCurrency(code: "TRY", symbol: "₺",    name: "Turkish Lira"),
    SupportedCurrency(code: "BRL", symbol: "R$",   name: "Brazilian Real"),
    SupportedCurrency(code: "HKD", symbol: "$",    name: "Hong Kong Dollar"),
    SupportedCurrency(code: "SEK", symbol: "kr",   name: "Swedish Krona"),
    SupportedCurrency(code: "NOK", symbol: "kr",   name: "Norwegian Krone"),
    SupportedCurrency(code: "PLN", symbol: "zł",   name: "Polish Zloty"),
    SupportedCurrency(code: "CZK", symbol: "Kč",   name: "Czech Koruna"),
]

/// Returns the SupportedCurrency for a given ISO code, or nil if not found.
func supportedCurrency(for code: String) -> SupportedCurrency? {
    SUPPORTED_CURRENCIES.first { $0.code == code }
}

/// Returns the symbol for a given currency code. Falls back to the code itself.
func symbolFor(currencyCode: String) -> String {
    supportedCurrency(for: currencyCode)?.symbol ?? currencyCode
}

func getTransTagIcon(transTag: String) -> String {
    switch transTag {
        case TRANS_TAG_TRANSPORT:     return "trans_type_transport"
        case TRANS_TAG_FOOD:          return "trans_type_food"
        case TRANS_TAG_HOUSING:       return "trans_type_housing"
        case TRANS_TAG_INSURANCE:     return "trans_type_insurance"
        case TRANS_TAG_MEDICAL:       return "trans_type_medical"
        case TRANS_TAG_SAVINGS:       return "trans_type_savings"
        case TRANS_TAG_PERSONAL:      return "trans_type_personal"
        case TRANS_TAG_ENTERTAINMENT: return "trans_type_entertainment"
        case TRANS_TAG_OTHERS:        return "trans_type_others"
        case TRANS_TAG_UTILITIES:     return "trans_type_utilities"
        default:                      return "trans_type_others"
    }
}

func getTransTagTitle(transTag: String) -> String {
    switch transTag {
        case TRANS_TAG_TRANSPORT:     return "Transport"
        case TRANS_TAG_FOOD:          return "Food"
        case TRANS_TAG_HOUSING:       return "Housing"
        case TRANS_TAG_INSURANCE:     return "Insurance"
        case TRANS_TAG_MEDICAL:       return "Medical"
        case TRANS_TAG_SAVINGS:       return "Savings"
        case TRANS_TAG_PERSONAL:      return "Personal"
        case TRANS_TAG_ENTERTAINMENT: return "Entertainment"
        case TRANS_TAG_OTHERS:        return "Others"
        case TRANS_TAG_UTILITIES:     return "Utilities"
        default:                      return "Unknown"
    }
}

func getDateFormatter(date: Date?, format: String = "yyyy-MM-dd") -> String {
    guard let date = date else { return "" }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = format
    return dateFormatter.string(from: date)
}

/// Extracts just the symbol portion from a legacy currency string.
/// e.g. "₹ INR" → "₹",  "$ USD" → "$",  "₹" → "₹"
func currencySymbol(from currency: String) -> String {
    currency.components(separatedBy: " ").first ?? currency
}

/// Maps an old-style CURRENCY_LIST entry (e.g. "₹ INR" or "₹") to an ISO code.
func isoCode(fromLegacyEntry entry: String) -> String {
    let parts = entry.components(separatedBy: " ")
    // If second part looks like a 3-letter code, use it
    if parts.count >= 2, parts[1].count == 3 {
        return parts[1]
    }
    // Fall back: try to match by symbol
    let symbol = parts.first ?? entry
    return SUPPORTED_CURRENCIES.first { $0.symbol == symbol }?.code ?? "INR"
}
