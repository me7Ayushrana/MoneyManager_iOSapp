//
//  ExportPDFReportViewModel.swift
//  MoneyManager
//
//  Created for TrackMint.
//  ViewModel handling range selection, predicate filtering, summary statistics calculation, and PDF export.
//

import SwiftUI
import CoreData
import Combine

enum PDFDateRangeOption: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case custom = "Custom Range"
    
    var id: String { rawValue }
}

@MainActor
class ExportPDFReportViewModel: ObservableObject {
    
    @Published var selectedRangeOption: PDFDateRangeOption = .thisMonth {
        didSet { updateDateRange() }
    }
    
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    
    @Published var isGenerating = false
    @Published var generatedPDFData: Data? = nil
    @Published var generatedPDFURL: URL? = nil
    @Published var showShareSheet = false
    
    @Published var alertMsg = ""
    @Published var showAlert = false
    
    // Live Summary Stats
    @Published var totalIncome: Double = 0.0
    @Published var totalExpense: Double = 0.0
    @Published var netBalance: Double = 0.0
    @Published var totalCount: Int = 0
    @Published var categoryBreakdown: [(tag: String, title: String, amount: Double, percentage: Double, color: UIColor)] = []
    
    var isCustomRangeInvalid: Bool {
        selectedRangeOption == .custom && startDate > endDate
    }
    
    var dateRangeTitleText: String {
        let formatter = DateFormatter()
        switch selectedRangeOption {
        case .thisWeek:
            formatter.dateFormat = "MMM dd"
            return "This Week (\(formatter.string(from: startDate)) – \(formatter.string(from: endDate)))"
        case .thisMonth:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: startDate)
        case .thisYear:
            formatter.dateFormat = "yyyy"
            return "Year \(formatter.string(from: startDate))"
        case .custom:
            formatter.dateFormat = "MMM dd, yyyy"
            return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
        }
    }
    
    init() {
        updateDateRange()
    }
    
    func updateDateRange() {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedRangeOption {
        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            startDate = calendar.date(from: components) ?? now
            endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? now
            
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
            if let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) {
                endDate = monthEnd
            } else {
                endDate = now
            }
            
        case .thisYear:
            let components = calendar.dateComponents([.year], from: now)
            startDate = calendar.date(from: components) ?? now
            if let yearEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate) {
                endDate = yearEnd
            } else {
                endDate = now
            }
            
        case .custom:
            // Keeps existing custom startDate and endDate
            break
        }
    }
    
    func evaluateSummary(moc: NSManagedObjectContext, exchangeService: ExchangeRateService, displayCurrency: String) {
        let fetchRequest = NSFetchRequest<ExpenseCD>(entityName: "ExpenseCD")
        
        // Start of day for startDate, End of day for endDate
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        fetchRequest.predicate = NSPredicate(
            format: "occuredOn >= %@ AND occuredOn <= %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occuredOn", ascending: false)]
        
        guard let results = try? moc.fetch(fetchRequest) else {
            totalIncome = 0.0
            totalExpense = 0.0
            netBalance = 0.0
            totalCount = 0
            categoryBreakdown = []
            return
        }
        
        totalCount = results.count
        var inc: Double = 0.0
        var exp: Double = 0.0
        var catDict = [String: Double]()
        
        for item in results {
            let code = item.resolvedCurrencyCode
            let converted = exchangeService.convertedAmount(item.amount, from: code, to: displayCurrency)
            
            if item.type == TRANS_TYPE_INCOME {
                inc += converted
            } else {
                exp += converted
                let tag = item.tag ?? TRANS_TAG_OTHERS
                catDict[tag, default: 0.0] += converted
            }
        }
        
        totalIncome = inc
        totalExpense = exp
        netBalance = inc - exp
        
        // Category Breakdown Calculation
        var breakdown: [(tag: String, title: String, amount: Double, percentage: Double, color: UIColor)] = []
        let totalCategorySpend = exp > 0 ? exp : 1.0
        
        for (tag, amt) in catDict {
            let pct = (amt / totalCategorySpend) * 100.0
            let title = getTransTagTitle(transTag: tag)
            let color = getTransTagColor(transTag: tag)
            breakdown.append((tag: tag, title: title, amount: amt, percentage: pct, color: color))
        }
        
        // Sort categories by highest spent
        categoryBreakdown = breakdown.sorted(by: { $0.amount > $1.amount })
    }
    
    func generateAndExportPDF(moc: NSManagedObjectContext, exchangeService: ExchangeRateService, displayCurrency: String) {
        guard !isCustomRangeInvalid else { return }
        
        isGenerating = true
        
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        let fetchRequest = NSFetchRequest<ExpenseCD>(entityName: "ExpenseCD")
        fetchRequest.predicate = NSPredicate(
            format: "occuredOn >= %@ AND occuredOn <= %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "occuredOn", ascending: false)]
        
        let results = (try? moc.fetch(fetchRequest)) ?? []
        
        var reportItems: [PDFReportItem] = []
        var inc: Double = 0.0
        var exp: Double = 0.0
        var catDict = [String: Double]()
        
        for item in results {
            let code = item.resolvedCurrencyCode
            let converted = exchangeService.convertedAmount(item.amount, from: code, to: displayCurrency)
            let isIncome = item.type == TRANS_TYPE_INCOME
            
            if isIncome {
                inc += converted
            } else {
                exp += converted
                let tag = item.tag ?? TRANS_TAG_OTHERS
                catDict[tag, default: 0.0] += converted
            }
            
            let pdfItem = PDFReportItem(
                date: item.occuredOn ?? Date(),
                title: item.title ?? "Transaction",
                categoryTag: item.tag ?? TRANS_TAG_OTHERS,
                isIncome: isIncome,
                originalAmount: item.amount,
                originalCurrency: code,
                convertedAmount: converted
            )
            reportItems.append(pdfItem)
        }
        
        var breakdown: [(tag: String, title: String, amount: Double, percentage: Double, color: UIColor)] = []
        let totalCatSpend = exp > 0 ? exp : 1.0
        for (tag, amt) in catDict {
            let pct = (amt / totalCatSpend) * 100.0
            let title = getTransTagTitle(transTag: tag)
            let color = getTransTagColor(transTag: tag)
            breakdown.append((tag: tag, title: title, amount: amt, percentage: pct, color: color))
        }
        breakdown.sort(by: { $0.amount > $1.amount })
        
        let genDateStr = getDateFormatter(date: Date(), format: "MMM dd, yyyy 'at' hh:mm a")
        let titleText = "Expense Report — \(dateRangeTitleText)"
        
        let pdfSummary = PDFReportSummary(
            title: titleText,
            dateRangeText: dateRangeTitleText,
            generatedDateText: genDateStr,
            displayCurrency: displayCurrency,
            totalIncome: inc,
            totalExpense: exp,
            netBalance: inc - exp,
            categoryTotals: breakdown,
            items: reportItems
        )
        
        let pdfData = PDFReportGenerator.shared.generatePDF(summary: pdfSummary)
        self.generatedPDFData = pdfData
        
        // Save PDF to Documents Directory & Temporary Directory
        let fileName = sanitizeFilename("TrackMint_Report_\(dateRangeTitleText).pdf")
        let fileManager = FileManager.default
        
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        try? pdfData.write(to: tempURL, options: .atomic)
        self.generatedPDFURL = tempURL
        
        // Also save persistent copy in Documents/
        if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docsURL = docsDir.appendingPathComponent(fileName)
            try? pdfData.write(to: docsURL, options: .atomic)
        }
        
        isGenerating = false
        showShareSheet = true
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>| ")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}
