//
//  ExportPDFReportView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  UI sheet for selecting date ranges, previewing summary stats, and exporting PDF reports via Share Sheet.
//

import SwiftUI
import CoreData

struct ExportPDFReportView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @StateObject private var viewModel = ExportPDFReportViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Bar
                    ToolbarModelView(
                        title: "Export PDF Report",
                        backButtonClick: { presentationMode.wrappedValue.dismiss() }
                    )
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // ── RANGE SELECTION CARD ──
                            VStack(alignment: .leading, spacing: 14) {
                                Text("DATE RANGE")
                                    .modifier(InterFont(.semiBold, size: 11))
                                    .foregroundColor(Color.text_secondary_color)
                                
                                // Range Pills / Segmented Control
                                HStack(spacing: 8) {
                                    ForEach(PDFDateRangeOption.allCases) { option in
                                        Button(action: {
                                            viewModel.selectedRangeOption = option
                                            viewModel.evaluateSummary(
                                                moc: managedObjectContext,
                                                exchangeService: exchangeService,
                                                displayCurrency: displayCurrency
                                            )
                                        }) {
                                            Text(option.rawValue)
                                                .modifier(InterFont(.semiBold, size: 12))
                                                .foregroundColor(viewModel.selectedRangeOption == option ? .white : Color.text_secondary_color)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(viewModel.selectedRangeOption == option ? Color.main_color : Color.secondary_color)
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                                
                                // Custom Date Pickers
                                if viewModel.selectedRangeOption == .custom {
                                    VStack(spacing: 12) {
                                        DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                                            .modifier(InterFont(.medium, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                            .onChange(of: viewModel.startDate) { _ in
                                                viewModel.evaluateSummary(
                                                    moc: managedObjectContext,
                                                    exchangeService: exchangeService,
                                                    displayCurrency: displayCurrency
                                                )
                                            }
                                        
                                        Divider().background(Color.primary_color)
                                        
                                        DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                                            .modifier(InterFont(.medium, size: 14))
                                            .foregroundColor(Color.text_primary_color)
                                            .onChange(of: viewModel.endDate) { _ in
                                                viewModel.evaluateSummary(
                                                    moc: managedObjectContext,
                                                    exchangeService: exchangeService,
                                                    displayCurrency: displayCurrency
                                                )
                                            }
                                    }
                                    .padding(14)
                                    .background(Color.secondary_color)
                                    .cornerRadius(12)
                                    
                                    // Validation Warning
                                    if viewModel.isCustomRangeInvalid {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(Color.main_red)
                                            Text("Start date cannot be after end date")
                                                .modifier(InterFont(.medium, size: 12))
                                                .foregroundColor(Color.main_red)
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.secondary_color.opacity(0.6))
                            .cornerRadius(16)
                            
                            // ── REPORT PREVIEW CARD ──
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("REPORT PREVIEW")
                                        .modifier(InterFont(.semiBold, size: 11))
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text("\(viewModel.totalCount) Transactions")
                                        .modifier(InterFont(.semiBold, size: 11))
                                        .foregroundColor(Color.main_color)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.main_color.opacity(0.12))
                                        .cornerRadius(8)
                                }
                                
                                Text(viewModel.dateRangeTitleText)
                                    .modifier(InterFont(.bold, size: 16))
                                    .foregroundColor(Color.text_primary_color)
                                
                                // Mini Summary Metrics
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("INCOME")
                                            .modifier(InterFont(.semiBold, size: 10))
                                            .foregroundColor(Color.main_green)
                                        CurrencyAmountView(
                                            amount: viewModel.totalIncome,
                                            currencyCode: displayCurrency,
                                            amountType: .subtitle_1,
                                            codeType: .caption,
                                            color: Color.main_green
                                        )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.main_green.opacity(0.08))
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("EXPENSE")
                                            .modifier(InterFont(.semiBold, size: 10))
                                            .foregroundColor(Color.main_red)
                                        CurrencyAmountView(
                                            amount: viewModel.totalExpense,
                                            currencyCode: displayCurrency,
                                            amountType: .subtitle_1,
                                            codeType: .caption,
                                            color: Color.main_red
                                        )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.main_red.opacity(0.08))
                                    .cornerRadius(10)
                                }
                                
                                // Category Allocation Preview Bar
                                if !viewModel.categoryBreakdown.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("TOP CATEGORY ALLOCATION")
                                            .modifier(InterFont(.semiBold, size: 10))
                                            .foregroundColor(Color.text_secondary_color)
                                        
                                        GeometryReader { geo in
                                            HStack(spacing: 2) {
                                                ForEach(viewModel.categoryBreakdown.prefix(5), id: \.tag) { cat in
                                                    Rectangle()
                                                        .fill(Color(cat.color))
                                                        .frame(width: max(4, geo.size.width * CGFloat(cat.percentage / 100.0)))
                                                }
                                            }
                                        }
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                        .clipped()
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(16)
                            .background(Color.secondary_color)
                            .cornerRadius(16)
                            
                            // ── GENERATE & SHARE BUTTON ──
                            Button(action: {
                                viewModel.generateAndExportPDF(
                                    moc: managedObjectContext,
                                    exchangeService: exchangeService,
                                    displayCurrency: displayCurrency
                                )
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.isGenerating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "doc.richtext.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Generate & Share PDF")
                                            .modifier(InterFont(.semiBold, size: 16))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(viewModel.isCustomRangeInvalid ? Color.gray : Color.main_color)
                                .cornerRadius(14)
                                .shadow(color: (viewModel.isCustomRangeInvalid ? Color.clear : Color.main_color.opacity(0.3)), radius: 8, x: 0, y: 4)
                            }
                            .disabled(viewModel.isCustomRangeInvalid || viewModel.isGenerating)
                            .padding(.top, 8)
                            
                            Spacer().frame(height: 40)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.evaluateSummary(
                    moc: managedObjectContext,
                    exchangeService: exchangeService,
                    displayCurrency: displayCurrency
                )
            }
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let pdfURL = viewModel.generatedPDFURL {
                    ActivityView(activityItems: [pdfURL])
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// UIKit UIActivityViewController Wrapper for SwiftUI Share Sheet
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
