//
//  ExpenseView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

struct ExpenseView: View {
    
    @AppStorage("isDarkMode") var isDarkMode = true
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    // CoreData
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(fetchRequest: ExpenseCD.getAllExpenseData(sortBy: ExpenseCDSort.occuredOn, ascending: false)) var expense: FetchedResults<ExpenseCD>
    
    @State private var filter: ExpenseCDFilterTime = .all
    @State private var showFilterSheet = false
    
    @State private var showOptionsSheet = false
    @State private var displayAbout = false
    @State private var displaySettings = false
    @State private var isAnimatingFAB = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack {
                    NavigationLink(destination: NavigationLazyView(ExpenseSettingsView()), isActive: $displaySettings, label: {})
                    NavigationLink(destination: NavigationLazyView(AboutView()), isActive: $displayAbout, label: {})
                    ToolbarModelView(title: "Dashboard", hasBackButt: false, button1Icon: IMAGE_OPTION_ICON, button2Icon: IMAGE_FILTER_ICON) { self.presentationMode.wrappedValue.dismiss() }
                        button1Method: { self.showOptionsSheet = true }
                        button2Method: { self.showFilterSheet = true }
                        .actionSheet(isPresented: $showFilterSheet) {
                            ActionSheet(title: Text("Select a filter"), buttons: [
                                    .default(Text("Overall")) { filter = .all },
                                    .default(Text("Last 7 days")) { filter = .week },
                                    .default(Text("Last 30 days")) { filter = .month },
                                    .cancel()
                             ])
                        }
                    ExpenseMainView(filter: filter)
                        .actionSheet(isPresented: $showOptionsSheet) {
                            ActionSheet(title: Text("Select an option"), buttons: [
                                    .default(Text("About")) { self.displayAbout = true },
                                    .default(Text("Settings")) { self.displaySettings = true },
                                    .cancel()
                             ])
                        }
                    Spacer()
                }.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: NavigationLazyView(AddExpenseView(viewModel: AddExpenseViewModel())),
                                       label: { Image("plus_icon").resizable().frame(width: 32.0, height: 32.0) })
                        .padding().background(Color.main_color).cornerRadius(35)
                        .scaleEffect(isAnimatingFAB ? 1.06 : 1.0)
                        .offset(y: isAnimatingFAB ? -4 : 0)
                        .shadow(color: Color.main_color.opacity(isAnimatingFAB ? 0.45 : 0.2), radius: isAnimatingFAB ? 10 : 5, x: 0, y: isAnimatingFAB ? 6 : 3)
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                isAnimatingFAB = true
                            }
                        }
                    }
                }.padding()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct ExpenseMainView: View {
    
    var filter: ExpenseCDFilterTime
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    @AppStorage(UD_EXPENSE_CURRENCY) var CURRENCY: String = ""
    @AppStorage("isDarkMode") var isDarkMode = true
    
    @State private var animateHeader = false
    @State private var animateItems = false
    
    init(filter: ExpenseCDFilterTime) {
        let sortDescriptor = NSSortDescriptor(key: "occuredOn", ascending: false)
        self.filter = filter
        if filter == .all {
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor])
        } else {
            var startDate: NSDate!
            let endDate: NSDate = NSDate()
            if filter == .week { startDate = Date().getLast7Day()! as NSDate }
            else if filter == .month { startDate = Date().getLast30Day()! as NSDate }
            else { startDate = Date().getLast6Month()! as NSDate }
            let predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@", startDate, endDate)
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
        }
    }
    
    private func getTotalBalance() -> String {
        var value = Double(0)
        for i in expense {
            if i.type == TRANS_TYPE_INCOME { value += i.amount }
            else if i.type == TRANS_TYPE_EXPENSE { value -= i.amount }
        }
        return "\(String(format: "%.2f", value))"
    }
    
    var body: some View {
        
        ScrollView(showsIndicators: false) {
            
            if fetchRequest.wrappedValue.isEmpty {
                LottieView(animType: .empty_face).frame(width: 300, height: 300)
                VStack {
                    TextView(text: "No Transaction Yet!", type: .h6).foregroundColor(Color.text_primary_color)
                    TextView(text: "Add a transaction and it will show up here", type: .body_1).foregroundColor(Color.text_secondary_color).padding(.top, 2)
                }.padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    TextView(text: "TOTAL BALANCE", type: .overline)
                        .foregroundColor(Color.text_secondary_color)
                        .padding(.top, 24)
                    TextView(text: "\(CURRENCY)\(getTotalBalance())", type: .h5)
                        .foregroundColor(Color.text_primary_color)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(Color.secondary_color)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.main_color.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .offset(y: animateHeader ? 0 : 30)
                .opacity(animateHeader ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateHeader)
                
                HStack(spacing: 8) {
                    NavigationLink(destination: NavigationLazyView(ExpenseFilterView(isIncome: true)),
                                   label: { ExpenseModelView(isIncome: true, filter: filter) })
                    NavigationLink(destination: NavigationLazyView(ExpenseFilterView(isIncome: false)),
                                   label: { ExpenseModelView(isIncome: false, filter: filter) })
                }
                .frame(maxWidth: .infinity)
                .offset(y: animateHeader ? 0 : 30)
                .opacity(animateHeader ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.12), value: animateHeader)
                
                Spacer().frame(height: 16)
                
                HStack {
                    TextView(text: "Recent Transaction", type: .subtitle_1).foregroundColor(Color.text_primary_color)
                    Spacer()
                }.padding(4)
                
                ForEach(self.fetchRequest.wrappedValue) { expenseObj in
                    let index = self.fetchRequest.wrappedValue.firstIndex(of: expenseObj) ?? 0
                    NavigationLink(destination: ExpenseDetailedView(expenseObj: expenseObj), label: {
                        ExpenseTransView(expenseObj: expenseObj)
                            .offset(y: animateItems ? 0 : 40)
                            .opacity(animateItems ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.04 + 0.25), value: animateItems)
                    })
                }
            }
            
            Spacer().frame(height: 150)
            
        }
        .padding(.horizontal, 8).padding(.top, 0)
        .onAppear {
            withAnimation {
                animateHeader = true
                animateItems = true
            }
        }
    }
}

struct ExpenseModelView: View {
    
    var isIncome: Bool
    var type: String
    var fetchRequest: FetchRequest<ExpenseCD>
    var expense: FetchedResults<ExpenseCD> { fetchRequest.wrappedValue }
    @AppStorage(UD_EXPENSE_CURRENCY) var CURRENCY: String = ""
    @AppStorage("isDarkMode") var isDarkMode = true
    
    private func getTotalValue() -> String {
        var value = Double(0)
        for i in expense { value += i.amount }
        return "\(String(format: "%.2f", value))"
    }
    
    init(isIncome: Bool, filter: ExpenseCDFilterTime, categTag: String? = nil) {
        self.isIncome = isIncome
        self.type = isIncome ? TRANS_TYPE_INCOME : TRANS_TYPE_EXPENSE
        let sortDescriptor = NSSortDescriptor(key: "occuredOn", ascending: false)
        if filter == .all {
            var predicate: NSPredicate!
            if let tag = categTag {
                predicate = NSPredicate(format: "type == %@ AND tag == %@", type, tag)
            } else { predicate = NSPredicate(format: "type == %@", type) }
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
        } else {
            var startDate: NSDate!
            let endDate: NSDate = NSDate()
            if filter == .week { startDate = Date().getLast7Day()! as NSDate }
            else if filter == .month { startDate = Date().getLast30Day()! as NSDate }
            else { startDate = Date().getLast6Month()! as NSDate }
            var predicate: NSPredicate!
            if let tag = categTag {
                predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@ AND type == %@ AND tag == %@", startDate, endDate, type, tag)
            } else { predicate = NSPredicate(format: "occuredOn >= %@ AND occuredOn <= %@ AND type == %@", startDate, endDate, type) }
            fetchRequest = FetchRequest<ExpenseCD>(entity: ExpenseCD.entity(), sortDescriptors: [sortDescriptor], predicate: predicate)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                TextView(text: isIncome ? "INCOME" : "EXPENSE", type: .overline)
                    .foregroundColor(Color.text_secondary_color)
                TextView(text: "\(CURRENCY)\(getTotalValue())", type: .subtitle_1, lineLimit: 1)
                    .foregroundColor(Color.text_primary_color)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(isIncome ? Color.main_green.opacity(0.15) : Color.main_red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: isIncome ? "arrow.down" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isIncome ? Color.main_green : Color.main_red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.secondary_color)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct ExpenseTransView: View {
    
    @ObservedObject var expenseObj: ExpenseCD
    @AppStorage(UD_EXPENSE_CURRENCY) var CURRENCY: String = ""
    @AppStorage("isDarkMode") var isDarkMode = true
    
    var body: some View {
        HStack {
            
            NavigationLink(destination: NavigationLazyView(ExpenseFilterView(categTag: expenseObj.tag)), label: {
                Image(getTransTagIcon(transTag: expenseObj.tag ?? ""))
                    .renderingMode(.template)
                    .resizable().frame(width: 24, height: 24).padding(16)
                    .foregroundColor(Color.main_color)
                    .background(Color.primary_color).cornerRadius(8)
            })
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextView(text: expenseObj.title ?? "", type: .subtitle_1, lineLimit: 1).foregroundColor(Color.text_primary_color)
                    Spacer()
                    TextView(text: "\(expenseObj.type == TRANS_TYPE_INCOME ? "+" : "-")\(CURRENCY)\(expenseObj.amount)", type: .subtitle_1)
                        .foregroundColor(expenseObj.type == TRANS_TYPE_INCOME ? Color.main_green : Color.main_red)
                }
                HStack {
                    TextView(text: getTransTagTitle(transTag: expenseObj.tag ?? ""), type: .body_2).foregroundColor(Color.text_primary_color)
                    Spacer()
                    TextView(text: getDateFormatter(date: expenseObj.occuredOn, format: "MMM dd, yyyy"), type: .body_2).foregroundColor(Color.text_primary_color)
                }
            }.padding(.leading, 4)
            
            Spacer()
            
        }
        .padding(8)
        .background(Color.secondary_color)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
}

struct ExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseView()
    }
}
 
 
 
