//
//  ExpenseDetailedView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

struct ExpenseDetailedView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    
    @StateObject var viewModel: ExpenseDetailedViewModel
    @State private var showEditExpense = false
    
    init(expenseObj: ExpenseCD) {
        _viewModel = StateObject(wrappedValue: ExpenseDetailedViewModel(expenseObj: expenseObj))
    }
    
    private var isIncome: Bool { viewModel.expenseObj.type == TRANS_TYPE_INCOME }
    private var originalCode: String { viewModel.expenseObj.resolvedCurrencyCode }
    private var originalAmount: Double { viewModel.expenseObj.amount }
    private var convertedAmount: Double {
        exchangeService.convertedAmount(originalAmount, from: originalCode, to: displayCurrency)
    }
    
    var body: some View {
        ZStack {
            Color.primary_color.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                ToolbarModelView(
                    title: isIncome ? "Income Detail" : "Expense Detail",
                    button1Icon: IMAGE_SHARE_ICON
                ) { presentationMode.wrappedValue.dismiss() }
                button1Method: { viewModel.shareNote() }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        
                        // ── Hero Amount Card ──
                        VStack(spacing: 8) {
                            // Type badge
                            Text(isIncome ? "INCOME" : "EXPENSE")
                                .modifier(InterFont(.semiBold, size: 11))
                                .foregroundColor(isIncome ? Color.main_green : Color.main_red)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background((isIncome ? Color.main_green : Color.main_red).opacity(0.14))
                                .cornerRadius(20)
                            
                            // Converted amount (display currency)
                            CurrencyAmountView(
                                amount: convertedAmount,
                                currencyCode: displayCurrency,
                                amountType: .h3,
                                codeType: .h6,
                                color: isIncome ? Color.main_green : Color.main_red
                            )
                            
                            // Original amount (if different currency)
                            if originalCode != displayCurrency {
                                HStack(spacing: 4) {
                                    Text("Original:")
                                        .modifier(InterFont(.regular, size: 12))
                                        .foregroundColor(Color.text_secondary_color)
                                    CurrencyAmountView(
                                        amount: originalAmount,
                                        currencyCode: originalCode,
                                        amountType: .body_1,
                                        codeType: .caption,
                                        color: Color.text_secondary_color
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 24).padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [
                                    (isIncome ? Color.main_green : Color.main_red).opacity(0.15),
                                    Color.secondary_color
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke((isIncome ? Color.main_green : Color.main_red).opacity(0.25), lineWidth: 1))
                        
                        // ── Detail Rows ──
                        VStack(spacing: 0) {
                            DetailRow(icon: "tag.fill", label: "Title", value: viewModel.expenseObj.title ?? "")
                            Divider().background(Color.primary_color).padding(.leading, 52)
                            DetailRow(icon: "folder.fill", label: "Category", value: getTransTagTitle(transTag: viewModel.expenseObj.tag ?? ""))
                            Divider().background(Color.primary_color).padding(.leading, 52)
                            DetailRow(icon: "calendar", label: "Date", value: getDateFormatter(date: viewModel.expenseObj.occuredOn, format: "EEEE, dd MMM yyyy"))
                            Divider().background(Color.primary_color).padding(.leading, 52)
                            DetailRow(icon: "clock.fill", label: "Time", value: getDateFormatter(date: viewModel.expenseObj.occuredOn, format: "hh:mm a"))
                            Divider().background(Color.primary_color).padding(.leading, 52)
                            DetailRow(icon: "banknote.fill", label: "Currency", value: "\(supportedCurrency(for: originalCode)?.name ?? originalCode) (\(originalCode))")
                            if let note = viewModel.expenseObj.note, !note.isEmpty {
                                Divider().background(Color.primary_color).padding(.leading, 52)
                                DetailRow(icon: "note.text", label: "Note", value: note)
                            }
                        }
                        .background(Color.secondary_color)
                        .cornerRadius(16)
                        
                        // ── Attachment ──
                        if let data = viewModel.expenseObj.imageAttached,
                           let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 200)
                                .cornerRadius(16)
                                .clipped()
                        }
                        
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 16).padding(.top, 16)
                }
                
                // Edit button
                HStack {
                    Spacer()
                    Button(action: { showEditExpense = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.main_color)
                            .cornerRadius(28)
                            .shadow(color: Color.main_color.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditExpense) {
            AddExpenseView(viewModel: AddExpenseViewModel(expenseObj: viewModel.expenseObj))
                .environment(\.managedObjectContext, managedObjectContext)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Reusable detail row

struct DetailRow: View {
    var icon: String
    var label: String
    var value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.main_color)
                .frame(width: 28, height: 28)
                .background(Color.main_color.opacity(0.12))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .modifier(InterFont(.regular, size: 11))
                    .foregroundColor(Color.text_secondary_color)
                Text(value)
                    .modifier(InterFont(.semiBold, size: 14))
                    .foregroundColor(Color.text_primary_color)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
