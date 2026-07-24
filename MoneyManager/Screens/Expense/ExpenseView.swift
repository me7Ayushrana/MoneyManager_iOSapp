//
//  ExpenseView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import CoreData

struct ExpenseView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    
    @State private var showAddExpense = false
    @State private var showFilter = false
    @State private var showSettings = false
    @State private var expenseFilter: ExpenseCDFilterTime = .all
    @State private var isAnimatingFAB = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Toolbar
                    HStack {
                        TextView(text: "Dashboard", type: .h6).foregroundColor(Color.text_primary_color)
                        Spacer()
                        // Theme toggle
                        Button(action: { themeManager.toggle() }) {
                            Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 22.0, height: 22.0)
                                .foregroundColor(Color.text_primary_color)
                        }.padding(.horizontal, 8)
                        // Filter
                        Button(action: { showFilter = true }) {
                            Image(IMAGE_FILTER_ICON).renderingMode(.template).resizable()
                                .frame(width: 28.0, height: 28.0).foregroundColor(Color.text_primary_color)
                        }.padding(.horizontal, 8)
                        // Settings
                        Button(action: { showSettings = true }) {
                            Image(IMAGE_OPTION_ICON).renderingMode(.template).resizable()
                                .frame(width: 28.0, height: 28.0).foregroundColor(Color.text_primary_color)
                        }
                    }
                    .padding(16).padding(.top, 30).padding(.horizontal, 8)
                    .background(Color.secondary_color)
                    
                    // Filter pills
                    HStack(spacing: 8) {
                        ForEach([("All", ExpenseCDFilterTime.all), ("Week", .week), ("Month", .month)], id: \.0) { label, filter in
                            Button(action: { expenseFilter = filter }) {
                                Text(label)
                                    .modifier(InterFont(.semiBold, size: 13))
                                    .foregroundColor(expenseFilter == filter ? .white : Color.text_secondary_color)
                                    .padding(.horizontal, 16).padding(.vertical, 7)
                                    .background(expenseFilter == filter ? Color.main_color : Color.secondary_color)
                                    .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    
                    // Main scrollable content
                    ExpenseMainView(filter: expenseFilter)
                        .environmentObject(themeManager)
                        .environmentObject(exchangeService)
                    
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddExpense = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isAnimatingFAB = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isAnimatingFAB = false }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.main_color)
                                .cornerRadius(30)
                                .shadow(color: Color.main_color.opacity(0.45), radius: 12, x: 0, y: 6)
                                .scaleEffect(isAnimatingFAB ? 1.15 : 1.0)
                        }
                    }.padding(24)
                }
                
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView(viewModel: AddExpenseViewModel())
                    .environment(\.managedObjectContext, managedObjectContext)
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showFilter) {
                ExpenseFilterView()
                    .environment(\.managedObjectContext, managedObjectContext)
                    .environmentObject(themeManager)
                    .environmentObject(exchangeService)
            }
            .sheet(isPresented: $showSettings) {
                ExpenseSettingsView()
                    .environment(\.managedObjectContext, managedObjectContext)
                    .environmentObject(themeManager)
                    .environmentObject(exchangeService)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
}

// MARK: - Main scrollable dashboard body

struct ExpenseMainView: View {
    
    var filter: ExpenseCDFilterTime
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @State private var animateHeader = false
    @State private var animateItems = false
    
    init(filter: ExpenseCDFilterTime) {
        let sort = NSSortDescriptor(key: "occuredOn", ascending: false)
        self.filter = filter
        if filter == .all {
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sort])
        } else {
            var startDate: NSDate!
            let endDate = NSDate()
            if filter == .week { startDate = Date().getLast7Day()! as NSDate }
            else if filter == .month { startDate = Date().getLast30Day()! as NSDate }
            else { startDate = Date().getLast6Month()! as NSDate }
            let predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@", startDate, endDate)
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sort], predicate: predicate)
        }
    }
    
    private func totalBalance() -> Double {
        expense.reduce(0.0) { acc, tx in
            let converted = exchangeService.convertedAmount(tx.amount, from: tx.resolvedCurrencyCode, to: displayCurrency)
            return tx.type == TRANS_TYPE_INCOME ? acc + converted : acc - converted
        }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if expense.isEmpty {
                LottieView(animType: .empty_face).frame(width: 300, height: 300)
                VStack {
                    TextView(text: "No Transaction Yet!", type: .h6).foregroundColor(Color.text_primary_color)
                    TextView(text: "Add a transaction and it will show up here", type: .body_1)
                        .foregroundColor(Color.text_secondary_color).padding(.top, 2)
                }.padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    
                    // ── Total Balance Card ──
                    VStack(spacing: 4) {
                        TextView(text: "TOTAL BALANCE", type: .overline)
                            .foregroundColor(Color.text_secondary_color)
                            .padding(.top, 20)
                        CurrencyAmountView.forHero(amount: totalBalance(), currencyCode: displayCurrency)
                            .padding(.bottom, 4)
                        // Offline rates notice
                        if exchangeService.isUsingCachedRates, let _ = exchangeService.lastUpdated {
                            HStack(spacing: 4) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 10))
                                Text(exchangeService.lastUpdatedLabel)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Color.text_secondary_color.opacity(0.7))
                            .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary_color)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.main_color.opacity(0.15), lineWidth: 1))
                    .offset(y: animateHeader ? 0 : -20)
                    .opacity(animateHeader ? 1 : 0)
                    
                    // ── Income / Expense Cards ──
                    HStack(spacing: 10) {
                        ExpenseSummaryCard(isIncome: true, filter: filter)
                            .environmentObject(exchangeService)
                        ExpenseSummaryCard(isIncome: false, filter: filter)
                            .environmentObject(exchangeService)
                    }
                    .offset(y: animateHeader ? 0 : -10)
                    .opacity(animateHeader ? 1 : 0)
                    
                    // ── Recent Transactions ──
                    HStack {
                        TextView(text: "Recent Transaction", type: .subtitle_1).foregroundColor(Color.text_primary_color)
                        Spacer()
                    }.padding(4)
                    
                    ForEach(expense) { expenseObj in
                        let index = expense.firstIndex(of: expenseObj) ?? 0
                        NavigationLink(
                            destination: ExpenseDetailedView(expenseObj: expenseObj)
                                .environmentObject(exchangeService),
                            label: {
                                ExpenseTransView(expenseObj: expenseObj)
                                    .environmentObject(exchangeService)
                                    .offset(y: animateItems ? 0 : 40)
                                    .opacity(animateItems ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.04 + 0.25), value: animateItems)
                            }
                        )
                    }
                }
                Spacer().frame(height: 120)
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            withAnimation { animateHeader = true; animateItems = true }
        }
        .ifAvailableRefreshable {
            exchangeService.refresh()
        }
    }
}

extension View {
    @ViewBuilder
    func ifAvailableRefreshable(action: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.refreshable { action() }
        } else {
            self
        }
    }
}

// MARK: - Summary Card (Income or Expense total)

struct ExpenseSummaryCard: View {
    
    var isIncome: Bool
    var filter: ExpenseCDFilterTime
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    private let type: String
    
    init(isIncome: Bool, filter: ExpenseCDFilterTime) {
        self.isIncome = isIncome
        self.filter = filter
        self.type = isIncome ? TRANS_TYPE_INCOME : TRANS_TYPE_EXPENSE
        let sort = NSSortDescriptor(key: "occuredOn", ascending: false)
        if filter == .all {
            let predicate = NSPredicate(format: "type == %@", type)
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sort], predicate: predicate)
        } else {
            var startDate: NSDate!
            let endDate = NSDate()
            if filter == .week { startDate = Date().getLast7Day()! as NSDate }
            else if filter == .month { startDate = Date().getLast30Day()! as NSDate }
            else { startDate = Date().getLast6Month()! as NSDate }
            let predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@ AND type == %@", startDate, endDate, type)
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sort], predicate: predicate)
        }
    }
    
    private func total() -> Double {
        expense.reduce(0.0) { acc, tx in
            acc + exchangeService.convertedAmount(tx.amount, from: tx.resolvedCurrencyCode, to: displayCurrency)
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                TextView(text: isIncome ? "INCOME" : "EXPENSE", type: .overline)
                    .foregroundColor(Color.text_secondary_color)
                CurrencyAmountView.forSummaryCard(amount: total(), currencyCode: displayCurrency, isIncome: isIncome)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(isIncome ? Color.main_green.opacity(0.18) : Color.main_red.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isIncome ? Color.main_green : Color.main_red)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.secondary_color)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.main_color.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Transaction row

struct ExpenseTransView: View {
    
    var expenseObj: ExpenseCD
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    var body: some View {
        let isIncome = expenseObj.type == TRANS_TYPE_INCOME
        let convertedAmt = exchangeService.convertedAmount(expenseObj.amount, from: expenseObj.resolvedCurrencyCode, to: displayCurrency)
        
        HStack(spacing: 12) {
            // Category icon
            Image(getTransTagIcon(transTag: expenseObj.tag ?? ""))
                .resizable().scaledToFit()
                .frame(width: 32, height: 32)
                .padding(10)
                .background(Color.main_color.opacity(0.12))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                TextView(text: expenseObj.title ?? "", type: .subtitle_1, lineLimit: 1)
                    .foregroundColor(Color.text_primary_color)
                TextView(text: getTransTagTitle(transTag: expenseObj.tag ?? ""), type: .body_2)
                    .foregroundColor(Color.text_secondary_color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                CurrencyAmountView.forTransaction(amount: convertedAmt, currencyCode: displayCurrency, isIncome: isIncome)
                Text(getDateFormatter(date: expenseObj.occuredOn, format: "MMM d, yyyy"))
                    .modifier(InterFont(.regular, size: 11))
                    .foregroundColor(Color.text_secondary_color)
                // Show original currency badge if different from display
                if expenseObj.resolvedCurrencyCode != displayCurrency {
                    Text("(\(symbolFor(currencyCode: expenseObj.resolvedCurrencyCode))\(String(format: "%.0f", expenseObj.amount)) \(expenseObj.resolvedCurrencyCode))")
                        .modifier(InterFont(.regular, size: 10))
                        .foregroundColor(Color.text_secondary_color.opacity(0.65))
                }
            }
        }
        .padding(12)
        .background(Color.secondary_color)
        .cornerRadius(14)
    }
}
