//
//  ExpenseView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI
import CoreData

// MARK: - Dashboard Filter Definition

enum DashboardFilterType: Equatable {
    case quick(ExpenseCDFilterTime) // .all, .week, .month
    case customMonthYear(month: Int, year: Int)
}

struct ExpenseView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    
    @State private var showAddExpense = false
    @State private var showFilter = false
    @State private var showSettings = false
    
    // Filter State
    @State private var activeFilter: DashboardFilterType = .quick(.all)
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showMonthYearPicker = false
    @State private var isAnimatingFAB = false
    
    // Time-based greeting helper
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        default:      return "Good Evening,"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Header Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(greetingText)
                                    .modifier(InterFont(.regular, size: 14))
                                    .foregroundColor(Color.text_secondary_color)
                                
                                HStack(spacing: 6) {
                                    Text("Ayush 👋")
                                        .modifier(InterFont(.bold, size: 28))
                                        .foregroundColor(Color.text_primary_color)
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                // Theme toggle
                                Button(action: { themeManager.toggle() }) {
                                    Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color.text_primary_color)
                                        .frame(width: 40, height: 40)
                                        .background(Color.secondary_color)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                }
                                
                                // Insights / Filter
                                Button(action: { showFilter = true }) {
                                    Image(systemName: "chart.pie.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Color.text_primary_color)
                                        .frame(width: 40, height: 40)
                                        .background(Color.secondary_color)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                }
                                
                                // Settings
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Color.text_primary_color)
                                        .frame(width: 40, height: 40)
                                        .background(Color.secondary_color)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                }
                            }
                        }
                        
                        // Financial summary subtitle pill
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("18%")
                                    .modifier(InterFont(.bold, size: 11))
                            }
                            .foregroundColor(Color.main_green)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.main_green.opacity(0.12))
                            .cornerRadius(12)
                            
                            Text("You saved 18% more this month.")
                                .modifier(InterFont(.medium, size: 13))
                                .foregroundColor(Color.text_secondary_color)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                    .background(Color.primary_color)
                    
                    // Filter pills bar (All, Week, Month, Month & Year picker)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([("All", ExpenseCDFilterTime.all), ("Week", .week), ("Month", .month)], id: \.0) { label, filter in
                                let isSelected = activeFilter == .quick(filter)
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        activeFilter = .quick(filter)
                                    }
                                }) {
                                    Text(label)
                                        .modifier(InterFont(.semiBold, size: 13))
                                        .foregroundColor(isSelected ? .white : Color.text_secondary_color)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(isSelected ? Color.main_color : Color.secondary_color)
                                        .cornerRadius(20)
                                        .shadow(color: isSelected ? Color.main_color.opacity(0.3) : Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                                }
                            }
                            
                            let isCustomSelected: Bool = {
                                if case .customMonthYear = activeFilter { return true }
                                return false
                            }()
                            
                            Button(action: { showMonthYearPicker = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(monthYearLabel(month: selectedMonth, year: selectedYear))
                                        .modifier(InterFont(.semiBold, size: 13))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(isCustomSelected ? .white : Color.text_secondary_color)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(isCustomSelected ? Color.main_color : Color.secondary_color)
                                .cornerRadius(20)
                                .shadow(color: isCustomSelected ? Color.main_color.opacity(0.3) : Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    }
                    
                    // Main scrollable content
                    ExpenseMainView(filterType: activeFilter)
                        .environmentObject(themeManager)
                        .environmentObject(exchangeService)
                    
                }
                
                // Floating Action Button (FAB)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showAddExpense = true
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { isAnimatingFAB = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isAnimatingFAB = false }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "2563EB"), Color(hex: "3B82F6")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 58, height: 58)
                                    .shadow(color: Color(hex: "2563EB").opacity(0.45), radius: 14, x: 0, y: 7)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isAnimatingFAB ? 1.12 : 1.0)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
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
            .sheet(isPresented: $showMonthYearPicker) {
                MonthYearPickerSheet(selectedMonth: $selectedMonth, selectedYear: $selectedYear) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        activeFilter = .customMonthYear(month: selectedMonth, year: selectedYear)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
    
    private func monthYearLabel(month: Int, year: Int) -> String {
        let fmt = DateFormatter()
        let symbol = fmt.shortMonthSymbols[month - 1]
        return "\(symbol) \(year)"
    }
}

// MARK: - Main scrollable dashboard body

struct ExpenseMainView: View {
    
    var filterType: DashboardFilterType
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    @State private var animateHeader = false
    @State private var animateItems = false
    @State private var isBalanceHidden = false
    
    init(filterType: DashboardFilterType) {
        let sort = NSSortDescriptor(key: "occuredOn", ascending: false)
        self.filterType = filterType
        
        switch filterType {
        case .quick(let filter):
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
            
        case .customMonthYear(let month, let year):
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
            
            let startDate = calendar.date(from: components)! as NSDate
            
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.second = -1
            let endDate = calendar.date(byAdding: endComponents, to: startDate as Date)! as NSDate
            
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
                VStack(spacing: 12) {
                    LottieView(animType: .empty_face).frame(width: 240, height: 240)
                    TextView(text: "No Transactions Found", type: .subtitle_1)
                        .foregroundColor(Color.text_primary_color)
                    TextView(text: "No transactions recorded for this period", type: .body_2)
                        .foregroundColor(Color.text_secondary_color)
                }
                .padding(.top, 40)
            } else {
                VStack(spacing: 16) {
                    
                    // ── Premium Hero Balance Card (30 pt radius) ──
                    ZStack(alignment: .bottomLeading) {
                        // Bezier Sparkline Curve Background
                        SparklineView(points: [15, 25, 20, 38, 30, 52, 45, 68, 55, 82], lineColor: Color.white.opacity(0.35))
                            .frame(height: 90)
                            .padding(.bottom, 12)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("AVAILABLE BALANCE")
                                        .modifier(InterFont(.semiBold, size: 11))
                                        .foregroundColor(Color.white.opacity(0.75))
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isBalanceHidden.toggle()
                                        }
                                    }) {
                                        Image(systemName: isBalanceHidden ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.white.opacity(0.85))
                                    }
                                }
                                
                                Spacer()
                                
                                // Capsule Account / Currency Button
                                HStack(spacing: 4) {
                                    Text("All Accounts")
                                        .modifier(InterFont(.semiBold, size: 11))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.white.opacity(0.18))
                                .cornerRadius(14)
                            }
                            
                            if isBalanceHidden {
                                Text("••••••••")
                                    .modifier(InterFont(.bold, size: 36))
                                    .foregroundColor(.white)
                                    .frame(height: 52, alignment: .leading)
                            } else {
                                CurrencyAmountView.forHero(amount: totalBalance(), currencyCode: displayCurrency)
                                    .foregroundColor(.white)
                            }
                            
                            if exchangeService.isUsingCachedRates, let _ = exchangeService.lastUpdated {
                                HStack(spacing: 4) {
                                    Image(systemName: "wifi.slash").font(.system(size: 10))
                                    Text(exchangeService.lastUpdatedLabel).font(.system(size: 10))
                                }
                                .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                        .padding(22)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 175)
                    .background(
                        LinearGradient(
                            colors: themeManager.isDarkMode ?
                                [Color(hex: "1E1B4B"), Color(hex: "312E81")] :
                                [Color(hex: "2563EB"), Color(hex: "6D5EF7")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(30)
                    .shadow(color: (themeManager.isDarkMode ? Color.black : Color(hex: "2563EB")).opacity(0.25), radius: 18, x: 0, y: 9)
                    .offset(y: animateHeader ? 0 : -20)
                    .opacity(animateHeader ? 1 : 0)
                    
                    // ── Income / Expense Summary Cards (24 pt radius) ──
                    HStack(spacing: 12) {
                        ExpenseSummaryCard(isIncome: true, filterType: filterType)
                            .environmentObject(exchangeService)
                        ExpenseSummaryCard(isIncome: false, filterType: filterType)
                            .environmentObject(exchangeService)
                    }
                    .offset(y: animateHeader ? 0 : -10)
                    .opacity(animateHeader ? 1 : 0)
                    
                    // ── Recent Transactions Header ──
                    HStack {
                        TextView(text: "Recent Transactions", type: .h5)
                            .foregroundColor(Color.text_primary_color)
                        Spacer()
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 4)
                    
                    // ── Transaction Cards (20 pt radius, 12 pt spacing) ──
                    VStack(spacing: 10) {
                        ForEach(expense) { expenseObj in
                            let index = expense.firstIndex(of: expenseObj) ?? 0
                            NavigationLink(
                                destination: ExpenseDetailedView(expenseObj: expenseObj)
                                    .environmentObject(exchangeService),
                                label: {
                                    ExpenseTransView(expenseObj: expenseObj)
                                        .environmentObject(exchangeService)
                                        .offset(y: animateItems ? 0 : 30)
                                        .opacity(animateItems ? 1 : 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.03 + 0.15), value: animateItems)
                                }
                            )
                        }
                    }
                }
                Spacer().frame(height: 120)
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation { animateHeader = true; animateItems = true }
        }
        .ifAvailableRefreshable {
            exchangeService.refresh()
        }
    }
}

// MARK: - Summary Card (Income or Expense total)

struct ExpenseSummaryCard: View {
    
    var isIncome: Bool
    var filterType: DashboardFilterType
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    private let type: String
    
    init(isIncome: Bool, filterType: DashboardFilterType) {
        self.isIncome = isIncome
        self.filterType = filterType
        self.type = isIncome ? TRANS_TYPE_INCOME : TRANS_TYPE_EXPENSE
        let sort = NSSortDescriptor(key: "occuredOn", ascending: false)
        
        switch filterType {
        case .quick(let filter):
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
            
        case .customMonthYear(let month, let year):
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
            
            let startDate = calendar.date(from: components)! as NSDate
            
            var endComponents = DateComponents()
            endComponents.month = 1
            endComponents.second = -1
            let endDate = calendar.date(byAdding: endComponents, to: startDate as Date)! as NSDate
            
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill((isIncome ? Color.main_green : Color.main_red).opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: isIncome ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isIncome ? Color.main_green : Color.main_red)
                }
                
                Spacer()
                
                // Micro trend badge
                HStack(spacing: 2) {
                    Text(isIncome ? "↑ 12%" : "↓ 4%")
                        .modifier(InterFont(.semiBold, size: 10))
                        .foregroundColor(isIncome ? Color.main_green : Color.main_red)
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background((isIncome ? Color.main_green : Color.main_red).opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                TextView(text: isIncome ? "INCOME" : "EXPENSE", type: .overline)
                    .foregroundColor(Color.text_secondary_color)
                CurrencyAmountView.forSummaryCard(amount: total(), currencyCode: displayCurrency, isIncome: isIncome)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.secondary_color)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.card_border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 5)
    }
}

// MARK: - Transaction Row Card (20 pt radius)

struct ExpenseTransView: View {
    
    var expenseObj: ExpenseCD
    @AppStorage(UD_DISPLAY_CURRENCY) var displayCurrency: String = "INR"
    @EnvironmentObject var exchangeService: ExchangeRateService
    
    var body: some View {
        let isIncome = expenseObj.type == TRANS_TYPE_INCOME
        let convertedAmt = exchangeService.convertedAmount(expenseObj.amount, from: expenseObj.resolvedCurrencyCode, to: displayCurrency)
        
        HStack(spacing: 14) {
            // Category icon badge (44x44 pt)
            Image(getTransTagIcon(transTag: expenseObj.tag ?? ""))
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .padding(10)
                .background(Color.main_color.opacity(0.12))
                .cornerRadius(14)
            
            VStack(alignment: .leading, spacing: 3) {
                TextView(text: expenseObj.title ?? "", type: .subtitle_1, lineLimit: 1)
                    .foregroundColor(Color.text_primary_color)
                TextView(text: getTransTagTitle(transTag: expenseObj.tag ?? ""), type: .body_2)
                    .foregroundColor(Color.text_secondary_color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                CurrencyAmountView.forTransaction(amount: convertedAmt, currencyCode: displayCurrency, isIncome: isIncome)
                Text(getDateFormatter(date: expenseObj.occuredOn, format: "MMM d, yyyy"))
                    .modifier(InterFont(.regular, size: 12))
                    .foregroundColor(Color.text_secondary_color)
                // Show original currency badge if different from display
                if expenseObj.resolvedCurrencyCode != displayCurrency {
                    Text("(\(symbolFor(currencyCode: expenseObj.resolvedCurrencyCode))\(String(format: "%.0f", expenseObj.amount)) \(expenseObj.resolvedCurrencyCode))")
                        .modifier(InterFont(.regular, size: 10))
                        .foregroundColor(Color.text_secondary_color.opacity(0.65))
                }
            }
        }
        .padding(14)
        .background(Color.secondary_color)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.card_border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Month & Year Picker Sheet Component

struct MonthYearPickerSheet: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    var onApply: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    let months = Calendar.current.shortMonthSymbols
    let years = Array(2020...2030)
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Select Month & Year")
                    .modifier(InterFont(.bold, size: 18))
                    .foregroundColor(Color.text_primary_color)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.text_secondary_color)
                }
            }
            .padding(.top, 20)
            
            // Year Selector Row
            HStack(spacing: 12) {
                Text("Year:")
                    .modifier(InterFont(.semiBold, size: 15))
                    .foregroundColor(Color.text_secondary_color)
                
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { yr in
                        Text(String(yr)).tag(yr)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 100)
                .clipped()
            }
            .padding(.horizontal, 16)
            .background(Color.secondary_color)
            .cornerRadius(12)
            
            // Month Grid
            VStack(alignment: .leading, spacing: 10) {
                Text("Month:")
                    .modifier(InterFont(.semiBold, size: 15))
                    .foregroundColor(Color.text_secondary_color)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(1...12, id: \.self) { m in
                        let isSelected = selectedMonth == m
                        Button(action: { selectedMonth = m }) {
                            Text(months[m - 1])
                                .modifier(InterFont(.semiBold, size: 14))
                                .foregroundColor(isSelected ? .white : Color.text_primary_color)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(isSelected ? Color.main_color : Color.secondary_color)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            
            // Apply Button
            Button(action: {
                onApply()
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Apply Filter")
                    .modifier(InterFont(.semiBold, size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.main_color)
                    .cornerRadius(12)
                    .shadow(color: Color.main_color.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color.primary_color.edgesIgnoringSafeArea(.all))
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
