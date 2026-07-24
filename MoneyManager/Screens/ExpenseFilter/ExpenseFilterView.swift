//
//  ExpenseFilterView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import CoreData

struct ExpenseFilterView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    @EnvironmentObject var budgetManager: BudgetManager
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    
    @State private var filterType: ExpenseCDFilterTime = .all
    @State private var transType = TRANS_TYPE_EXPENSE
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ToolbarModelView(title: "Filter & Insights") { self.presentationMode.wrappedValue.dismiss() }
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            
                            // Income / Expense type toggle
                            HStack(spacing: 12) {
                                Button(action: { transType = TRANS_TYPE_EXPENSE }) {
                                    HStack {
                                        Spacer()
                                        Text("Expenses")
                                            .modifier(InterFont(.semiBold, size: 14))
                                            .foregroundColor(transType == TRANS_TYPE_EXPENSE ? .white : Color.text_secondary_color)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(transType == TRANS_TYPE_EXPENSE ? Color.main_red : Color.secondary_color)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: { transType = TRANS_TYPE_INCOME }) {
                                    HStack {
                                        Spacer()
                                        Text("Income")
                                            .modifier(InterFont(.semiBold, size: 14))
                                            .foregroundColor(transType == TRANS_TYPE_INCOME ? .white : Color.text_secondary_color)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .background(transType == TRANS_TYPE_INCOME ? Color.main_green : Color.secondary_color)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 12)
                            
                            // Time frame pills
                            HStack(spacing: 8) {
                                ForEach([("All", ExpenseCDFilterTime.all), ("Week", .week), ("Month", .month)], id: \.0) { label, filter in
                                    Button(action: { filterType = filter }) {
                                        Text(label)
                                            .modifier(InterFont(.semiBold, size: 13))
                                            .foregroundColor(filterType == filter ? .white : Color.text_secondary_color)
                                            .padding(.horizontal, 16).padding(.vertical, 7)
                                            .background(filterType == filter ? Color.main_color : Color.secondary_color)
                                            .cornerRadius(20)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            
                            // Filter Content (Chart + Transactions)
                            ExpenseFilterContentView(filterType: filterType, isIncome: transType == TRANS_TYPE_INCOME, selectedCategory: selectedCategory)
                                .environmentObject(exchangeService)
                                .environmentObject(budgetManager)
                            
                            Spacer().frame(height: 50)
                        }
                        .padding(.top, 12)
                    }
                }
                .edgesIgnoringSafeArea(.top)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

struct ExpenseFilterContentView: View {
    
    var filterType: ExpenseCDFilterTime
    var isIncome: Bool
    var selectedCategory: String?
    
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var exchangeService: ExchangeRateService
    @EnvironmentObject var budgetManager: BudgetManager
    
    @State private var animateChart = false
    
    init(filterType: ExpenseCDFilterTime, isIncome: Bool, selectedCategory: String? = nil) {
        self.filterType = filterType
        self.isIncome = isIncome
        self.selectedCategory = selectedCategory
        
        let type = isIncome ? TRANS_TYPE_INCOME : TRANS_TYPE_EXPENSE
        let sortDescriptor = NSSortDescriptor(key: "occuredOn", ascending: false)
        
        if filterType == .all {
            var predicate: NSPredicate
            if let cat = selectedCategory {
                predicate = NSPredicate(format: "type == %@ AND tag == %@", type, cat)
            } else {
                predicate = NSPredicate(format: "type == %@", type)
            }
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
        } else {
            var startDate: NSDate!
            let endDate: NSDate = NSDate()
            if filterType == .week { startDate = Date().getLast7Day()! as NSDate }
            else if filterType == .month { startDate = Date().getLast30Day()! as NSDate }
            else { startDate = Date().getLast6Month()! as NSDate }
            
            var predicate: NSPredicate
            if let cat = selectedCategory {
                predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@ AND type == %@ AND tag == %@", startDate, endDate, type, cat)
            } else {
                predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@ AND type == %@", startDate, endDate, type)
            }
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
        }
    }
    
    private func getTotalValue() -> Double {
        expense.reduce(0.0) { acc, tx in
            acc + exchangeService.convertedAmount(tx.amount, from: tx.resolvedCurrencyCode, to: displayCurrency)
        }
    }
    
    private func getChartModel() -> [ChartModel] {
        var categoryTotals = [String: Double]()
        for i in expense {
            let converted = exchangeService.convertedAmount(i.amount, from: i.resolvedCurrencyCode, to: displayCurrency)
            let tag = getTransTagTitle(transTag: i.tag ?? "")
            categoryTotals[tag, default: 0.0] += converted
        }
        return categoryTotals.map { ChartModel(transType: $0.key, transAmount: $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // If category is selected or viewing expenses, show Category Budget Progress if applicable
            if let cat = selectedCategory, !isIncome {
                BudgetProgressView(tag: cat, spentConverted: getTotalValue(), displayCurrency: displayCurrency)
                    .environmentObject(budgetManager)
                    .padding(.horizontal, 12)
            }
            
            // Chart Card
            if !expense.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextView(text: "Total \(isIncome ? "Income" : "Expense")", type: .overline)
                            .foregroundColor(Color.text_secondary_color)
                        Spacer()
                        CurrencyAmountView(amount: getTotalValue(), currencyCode: displayCurrency, amountType: .subtitle_1, codeType: .caption, color: isIncome ? Color.main_green : Color.main_red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    
                    ChartView(label: "", entries: ChartModel.getTransaction(transactions: getChartModel()))
                        .scaleEffect(animateChart ? 1.0 : 0.8)
                        .opacity(animateChart ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateChart)
                }
                .padding(.bottom, 12)
                .background(Color.secondary_color)
                .cornerRadius(16)
                .padding(.horizontal, 12)
            } else {
                VStack(spacing: 8) {
                    LottieView(animType: .empty_face).frame(width: 200, height: 200)
                    TextView(text: "No Transactions Found", type: .subtitle_1).foregroundColor(Color.text_primary_color)
                }
                .padding(.vertical, 30)
            }
            
            // List of Filtered Transactions
            if !expense.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextView(text: "Transactions (\(expense.count))", type: .subtitle_1)
                            .foregroundColor(Color.text_primary_color)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    ForEach(expense) { item in
                        NavigationLink(
                            destination: ExpenseDetailedView(expenseObj: item).environmentObject(exchangeService),
                            label: {
                                ExpenseTransView(expenseObj: item).environmentObject(exchangeService)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .onAppear { animateChart = true }
    }
}
