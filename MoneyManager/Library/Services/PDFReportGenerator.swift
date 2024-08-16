//
//  PDFReportGenerator.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Renders professional financial PDF reports using UIGraphicsPDFRenderer.
//

import UIKit
import PDFKit

struct PDFReportItem {
    let date: Date
    let title: String
    let categoryTag: String
    let isIncome: Bool
    let originalAmount: Double
    let originalCurrency: String
    let convertedAmount: Double
}

struct PDFReportSummary {
    let title: String
    let dateRangeText: String
    let generatedDateText: String
    let displayCurrency: String
    let totalIncome: Double
    let totalExpense: Double
    let netBalance: Double
    let categoryTotals: [(tag: String, title: String, amount: Double, percentage: Double, color: UIColor)]
    let items: [PDFReportItem]
}

class PDFReportGenerator {
    
    static let shared = PDFReportGenerator()
    
    // Page dimensions (US Letter)
    private let pageWidth: CGFloat = 612.0
    private let pageHeight: CGFloat = 792.0
    private let margin: CGFloat = 36.0
    
    private var printableWidth: CGFloat { pageWidth - (margin * 2) }
    
    func generatePDF(summary: PDFReportSummary) -> Data {
        let rendererBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: rendererBounds)
        
        return renderer.pdfData { context in
            var currentPage = 1
            var totalPagesEstimate = calculateTotalPages(summary: summary)
            
            context.beginPage()
            var currentY: CGFloat = margin
            
            // 1. Header Banner
            currentY = drawHeader(y: currentY, summary: summary)
            
            // 2. Summary Cards (Income, Expense, Net Balance)
            currentY = drawSummaryCards(y: currentY, summary: summary)
            
            // 3. Category Allocation Visual Breakdown
            currentY = drawCategoryBreakdown(y: currentY, summary: summary)
            
            // 4. Transaction Table Section
            drawTransactionTable(context: context, currentY: &currentY, currentPage: &currentPage, totalPages: &totalPagesEstimate, summary: summary)
            
            // Draw footers on all pages
            // (Footers are drawn during page creation)
        }
    }
    
    // MARK: - Header
    
    private func drawHeader(y: CGFloat, summary: PDFReportSummary) -> CGFloat {
        var cursorY = y
        
        // Brand Badge Background
        let brandRect = CGRect(x: margin, y: cursorY, width: 36, height: 36)
        let brandPath = UIBezierPath(roundedRect: brandRect, cornerRadius: 8)
        UIColor(red: 0.31, green: 0.45, blue: 0.87, alpha: 0.15).setFill()
        brandPath.fill()
        
        // Brand Letter "tm"
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor(red: 0.31, green: 0.45, blue: 0.87, alpha: 1.0)
        ]
        "tm".draw(at: CGPoint(x: margin + 8, y: cursorY + 8), withAttributes: brandAttributes)
        
        // Title & Subtitle
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        ]
        summary.title.draw(at: CGPoint(x: margin + 48, y: cursorY), withAttributes: titleAttributes)
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1.0)
        ]
        let dateRangeStr = "Period: \(summary.dateRangeText) • Generated: \(summary.generatedDateText)"
        dateRangeStr.draw(at: CGPoint(x: margin + 48, y: cursorY + 22), withAttributes: subtitleAttributes)
        
        cursorY += 46
        
        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: cursorY))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: cursorY))
        UIColor(red: 0.88, green: 0.88, blue: 0.92, alpha: 1.0).setStroke()
        linePath.lineWidth = 1.0
        linePath.stroke()
        
        return cursorY + 16
    }
    
    // MARK: - Summary Cards
    
    private func drawSummaryCards(y: CGFloat, summary: PDFReportSummary) -> CGFloat {
        var cursorY = y
        
        let cardWidth = (printableWidth - 24) / 3.0
        let cardHeight: CGFloat = 58.0
        
        let currencySymbol = symbolFor(currencyCode: summary.displayCurrency)
        
        // 1. Total Income Card
        drawCard(
            rect: CGRect(x: margin, y: cursorY, width: cardWidth, height: cardHeight),
            title: "TOTAL INCOME",
            value: "+\(currencySymbol)\(String(format: "%.2f", summary.totalIncome))",
            color: UIColor(red: 0.11, green: 0.78, blue: 0.54, alpha: 1.0)
        )
        
        // 2. Total Expense Card
        drawCard(
            rect: CGRect(x: margin + cardWidth + 12, y: cursorY, width: cardWidth, height: cardHeight),
            title: "TOTAL EXPENSES",
            value: "-\(currencySymbol)\(String(format: "%.2f", summary.totalExpense))",
            color: UIColor(red: 0.91, green: 0.29, blue: 0.23, alpha: 1.0)
        )
        
        // 3. Net Balance Card
        let netColor = summary.netBalance >= 0 ? UIColor(red: 0.11, green: 0.78, blue: 0.54, alpha: 1.0) : UIColor(red: 0.91, green: 0.29, blue: 0.23, alpha: 1.0)
        let netSign = summary.netBalance >= 0 ? "+" : "-"
        drawCard(
            rect: CGRect(x: margin + (cardWidth + 12) * 2, y: cursorY, width: cardWidth, height: cardHeight),
            title: "NET BALANCE",
            value: "\(netSign)\(currencySymbol)\(String(format: "%.2f", abs(summary.netBalance)))",
            color: netColor
        )
        
        cursorY += cardHeight + 20
        return cursorY
    }
    
    private func drawCard(rect: CGRect, title: String, value: String, color: UIColor) {
        let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        color.withAlphaComponent(0.08).setFill()
        bgPath.fill()
        
        let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        color.withAlphaComponent(0.3).setStroke()
        borderPath.lineWidth = 1.0
        borderPath.stroke()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1.0)
        ]
        title.draw(at: CGPoint(x: rect.origin.x + 12, y: rect.origin.y + 10), withAttributes: titleAttrs)
        
        let valAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: color
        ]
        value.draw(at: CGPoint(x: rect.origin.x + 12, y: rect.origin.y + 26), withAttributes: valAttrs)
    }
    
    // MARK: - Category Breakdown
    
    private func drawCategoryBreakdown(y: CGFloat, summary: PDFReportSummary) -> CGFloat {
        guard !summary.categoryTotals.isEmpty else { return y }
        
        var cursorY = y
        
        // Section Title
        let secTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        ]
        "CATEGORY SPENDING BREAKDOWN".draw(at: CGPoint(x: margin, y: cursorY), withAttributes: secTitleAttrs)
        cursorY += 18
        
        // Stacked Progress Bar
        let barRect = CGRect(x: margin, y: cursorY, width: printableWidth, height: 12)
        let barBg = UIBezierPath(roundedRect: barRect, cornerRadius: 6)
        UIColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1.0).setFill()
        barBg.fill()
        
        var barX = margin
        for cat in summary.categoryTotals {
            let segmentWidth = printableWidth * CGFloat(cat.percentage / 100.0)
            if segmentWidth > 1 {
                let segRect = CGRect(x: barX, y: cursorY, width: segmentWidth, height: 12)
                let segPath = UIBezierPath(roundedRect: segRect, cornerRadius: 4)
                cat.color.setFill()
                segPath.fill()
                barX += segmentWidth
            }
        }
        cursorY += 20
        
        // Grid legend for top categories (up to 6)
        let maxCats = min(summary.categoryTotals.count, 6)
        let currencySymbol = symbolFor(currencyCode: summary.displayCurrency)
        
        let colWidth = printableWidth / 2.0
        for i in 0..<maxCats {
            let cat = summary.categoryTotals[i]
            let col = i % 2
            let row = i / 2
            let itemX = margin + (CGFloat(col) * colWidth)
            let itemY = cursorY + (CGFloat(row) * 16.0)
            
            // Dot indicator
            let dotRect = CGRect(x: itemX, y: itemY + 3, width: 8, height: 8)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            cat.color.setFill()
            dotPath.fill()
            
            // Category text
            let text = "\(cat.title): \(currencySymbol)\(String(format: "%.2f", cat.amount)) (\(String(format: "%.1f", cat.percentage))%)"
            let catAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)
            ]
            text.draw(at: CGPoint(x: itemX + 14, y: itemY), withAttributes: catAttrs)
        }
        
        let numRows = ceil(Double(maxCats) / 2.0)
        cursorY += (CGFloat(numRows) * 16.0) + 16
        
        return cursorY
    }
    
    // MARK: - Transaction Table
    
    private func drawTransactionTable(
        context: UIGraphicsPDFRendererContext,
        currentY: inout CGFloat,
        currentPage: inout Int,
        totalPages: inout Int,
        summary: PDFReportSummary
    ) {
        // Section Header
        let secTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        ]
        "TRANSACTION DETAILS".draw(at: CGPoint(x: margin, y: currentY), withAttributes: secTitleAttrs)
        currentY += 20
        
        // Zero transactions edge case
        if summary.items.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
            ]
            "No transactions recorded for the selected period.".draw(at: CGPoint(x: margin, y: currentY), withAttributes: emptyAttrs)
            drawFooter(page: currentPage, totalPages: totalPages, summary: summary)
            return
        }
        
        drawTableHeader(y: currentY)
        currentY += 22
        
        let currencySymbol = symbolFor(currencyCode: summary.displayCurrency)
        
        for item in summary.items {
            let rowHeight: CGFloat = 20.0
            
            // Page overflow check
            if currentY + rowHeight > pageHeight - margin - 30 {
                drawFooter(page: currentPage, totalPages: totalPages, summary: summary)
                context.beginPage()
                currentPage += 1
                currentY = margin + 10
                
                drawTableHeader(y: currentY)
                currentY += 22
            }
            
            // Row Content
            let dateStr = getDateFormatter(date: item.date, format: "MMM dd, yyyy")
            let typeStr = item.isIncome ? "Income" : "Expense"
            let catTitle = getTransTagTitle(transTag: item.categoryTag)
            
            let amtColor = item.isIncome ? UIColor(red: 0.11, green: 0.78, blue: 0.54, alpha: 1.0) : UIColor(red: 0.91, green: 0.29, blue: 0.23, alpha: 1.0)
            let amtPrefix = item.isIncome ? "+" : "-"
            let amtStr = "\(amtPrefix)\(currencySymbol)\(String(format: "%.2f", item.convertedAmount))"
            
            let font = UIFont.systemFont(ofSize: 9.5, weight: .regular)
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
            ]
            let amtAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5, weight: .bold),
                .foregroundColor: amtColor
            ]
            
            // Column Positions: Date(80), Title(170), Category(110), Type(60), Amount(120)
            dateStr.draw(at: CGPoint(x: margin, y: currentY), withAttributes: rowAttrs)
            
            let truncatedTitle = truncateString(item.title, maxLength: 26)
            truncatedTitle.draw(at: CGPoint(x: margin + 85, y: currentY), withAttributes: rowAttrs)
            
            catTitle.draw(at: CGPoint(x: margin + 255, y: currentY), withAttributes: rowAttrs)
            typeStr.draw(at: CGPoint(x: margin + 370, y: currentY), withAttributes: rowAttrs)
            amtStr.draw(at: CGPoint(x: margin + 430, y: currentY), withAttributes: amtAttrs)
            
            // Light row divider
            let rowLine = UIBezierPath()
            rowLine.move(to: CGPoint(x: margin, y: currentY + 16))
            rowLine.addLine(to: CGPoint(x: pageWidth - margin, y: currentY + 16))
            UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0).setStroke()
            rowLine.lineWidth = 0.5
            rowLine.stroke()
            
            currentY += rowHeight
        }
        
        drawFooter(page: currentPage, totalPages: totalPages, summary: summary)
    }
    
    private func drawTableHeader(y: CGFloat) {
        let bgRect = CGRect(x: margin, y: y, width: printableWidth, height: 18)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 4)
        UIColor(red: 0.94, green: 0.94, blue: 0.97, alpha: 1.0).setFill()
        bgPath.fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1.0)
        ]
        
        "DATE".draw(at: CGPoint(x: margin + 4, y: y + 3), withAttributes: headerAttrs)
        "DESCRIPTION".draw(at: CGPoint(x: margin + 85, y: y + 3), withAttributes: headerAttrs)
        "CATEGORY".draw(at: CGPoint(x: margin + 255, y: y + 3), withAttributes: headerAttrs)
        "TYPE".draw(at: CGPoint(x: margin + 370, y: y + 3), withAttributes: headerAttrs)
        "AMOUNT".draw(at: CGPoint(x: margin + 430, y: y + 3), withAttributes: headerAttrs)
    }
    
    // MARK: - Footer
    
    private func drawFooter(page: Int, totalPages: Int, summary: PDFReportSummary) {
        let footerY = pageHeight - margin + 6
        
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: footerY - 8))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: footerY - 8))
        UIColor(red: 0.88, green: 0.88, blue: 0.92, alpha: 1.0).setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()
        
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8.5, weight: .regular),
            .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        ]
        
        let pageStr = "Page \(page) of \(totalPages)"
        pageStr.draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)
        
        let brandStr = "Generated by TrackMint App"
        let brandWidth = brandStr.size(withAttributes: footerAttrs).width
        brandStr.draw(at: CGPoint(x: pageWidth - margin - brandWidth, y: footerY), withAttributes: footerAttrs)
    }
    
    // MARK: - Helpers
    
    private func calculateTotalPages(summary: PDFReportSummary) -> Int {
        if summary.items.isEmpty { return 1 }
        
        // First page content height available for table
        let firstPageUsed: CGFloat = margin + 46 + 16 + 58 + 20 + (summary.categoryTotals.isEmpty ? 0 : 80) + 20 + 22
        let firstPageAvailable = pageHeight - margin - 30 - firstPageUsed
        let firstPageRows = max(1, Int(firstPageAvailable / 20.0))
        
        if summary.items.count <= firstPageRows {
            return 1
        }
        
        let remainingItems = summary.items.count - firstPageRows
        let subsequentPageAvailable = pageHeight - (margin * 2) - 30 - 22
        let subsequentPageRows = max(1, Int(subsequentPageAvailable / 20.0))
        
        let extraPages = ceil(Double(remainingItems) / Double(subsequentPageRows))
        return 1 + Int(extraPages)
    }
    
    private func truncateString(_ str: String, maxLength: Int) -> String {
        if str.count <= maxLength { return str }
        let index = str.index(str.startIndex, offsetBy: maxLength - 3)
        return String(str[..<index]) + "..."
    }
}

// Category color helper
func getTransTagColor(transTag: String) -> UIColor {
    switch transTag {
    case TRANS_TAG_TRANSPORT:     return UIColor(red: 0.31, green: 0.45, blue: 0.87, alpha: 1.0) // #4E73DF
    case TRANS_TAG_FOOD:          return UIColor(red: 0.91, green: 0.29, blue: 0.23, alpha: 1.0) // #E74A3B
    case TRANS_TAG_HOUSING:       return UIColor(red: 0.96, green: 0.76, blue: 0.24, alpha: 1.0) // #F6C23E
    case TRANS_TAG_INSURANCE:     return UIColor(red: 0.11, green: 0.78, blue: 0.54, alpha: 1.0) // #1CC88A
    case TRANS_TAG_MEDICAL:       return UIColor(red: 0.21, green: 0.73, blue: 0.80, alpha: 1.0) // #36B9CC
    case TRANS_TAG_SAVINGS:       return UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0) // #6F42C1
    case TRANS_TAG_PERSONAL:      return UIColor(red: 0.91, green: 0.24, blue: 0.55, alpha: 1.0) // #E83E8C
    case TRANS_TAG_ENTERTAINMENT: return UIColor(red: 0.99, green: 0.49, blue: 0.08, alpha: 1.0) // #FD7E14
    case TRANS_TAG_UTILITIES:     return UIColor(red: 0.13, green: 0.79, blue: 0.59, alpha: 1.0) // #20C997
    default:                      return UIColor(red: 0.52, green: 0.53, blue: 0.59, alpha: 1.0) // #858796
    }
}
