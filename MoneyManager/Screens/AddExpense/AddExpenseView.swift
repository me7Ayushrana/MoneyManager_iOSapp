//
//  AddExpenseView.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

struct AddExpenseView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Environment(\.managedObjectContext) var managedObjectContext
    @State private var confirmDelete = false
    @State var showAttachSheet = false
    @EnvironmentObject var themeManager: ThemeManager
    
    @StateObject var viewModel: AddExpenseViewModel
    
    let typeOptions = [
        DropdownOption(key: TRANS_TYPE_INCOME, val: "Income"),
        DropdownOption(key: TRANS_TYPE_EXPENSE, val: "Expense")
    ]
    
    let tagOptions = [
        DropdownOption(key: TRANS_TAG_TRANSPORT, val: "Transport"),
        DropdownOption(key: TRANS_TAG_FOOD, val: "Food"),
        DropdownOption(key: TRANS_TAG_HOUSING, val: "Housing"),
        DropdownOption(key: TRANS_TAG_INSURANCE, val: "Insurance"),
        DropdownOption(key: TRANS_TAG_MEDICAL, val: "Medical"),
        DropdownOption(key: TRANS_TAG_SAVINGS, val: "Savings"),
        DropdownOption(key: TRANS_TAG_PERSONAL, val: "Personal"),
        DropdownOption(key: TRANS_TAG_ENTERTAINMENT, val: "Entertainment"),
        DropdownOption(key: TRANS_TAG_UTILITIES, val: "Utilities"),
        DropdownOption(key: TRANS_TAG_OTHERS, val: "Others")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    
                    Group {
                        if viewModel.expenseObj == nil {
                            ToolbarModelView(title: "Add Transaction") { self.presentationMode.wrappedValue.dismiss() }
                        } else {
                            ToolbarModelView(title: "Edit Transaction", button1Icon: IMAGE_DELETE_ICON) { self.presentationMode.wrappedValue.dismiss() }
                                button1Method: { self.confirmDelete = true }
                        }
                    }.alert(isPresented: $confirmDelete,
                            content: {
                                Alert(title: Text(APP_NAME),
                                      message: Text("Are you sure you want to delete this transaction?"),
                                      primaryButton: .destructive(Text("Delete")) {
                                          viewModel.deleteTransaction(managedObjectContext: self.managedObjectContext)
                                      },
                                      secondaryButton: .cancel(Text("Cancel"), action: { confirmDelete = false }))
                            })
                    
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 12) {
                            
                            // Title
                            TextField("Title", text: $viewModel.title)
                                .modifier(InterFont(.regular, size: 16))
                                .accentColor(Color.text_primary_color)
                                .frame(height: 50).padding(.leading, 16)
                                .background(Color.secondary_color)
                                .cornerRadius(8)
                            
                            // Amount + currency symbol prefix + prominent calculator toggle
                            VStack(spacing: 8) {
                                HStack(spacing: 0) {
                                    Text(symbolFor(currencyCode: viewModel.selectedCurrencyCode))
                                        .modifier(InterFont(.semiBold, size: 18))
                                        .foregroundColor(Color.main_color)
                                        .frame(width: 48, height: 50)
                                        .background(Color.main_color.opacity(0.12))
                                    
                                    TextField("Amount or math (e.g. 50+20)", text: $viewModel.amount)
                                        .modifier(InterFont(.regular, size: 16))
                                        .accentColor(Color.text_primary_color)
                                        .frame(height: 50).padding(.leading, 12)
                                        .keyboardType(.numbersAndPunctuation)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            viewModel.showCalculator.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "calculator.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text(viewModel.showCalculator ? "Close" : "Calc")
                                                .modifier(InterFont(.semiBold, size: 12))
                                        }
                                        .foregroundColor(viewModel.showCalculator ? .white : Color.main_color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(viewModel.showCalculator ? Color.main_color : Color.main_color.opacity(0.14))
                                        .cornerRadius(6)
                                        .padding(.trailing, 8)
                                    }
                                }
                                .background(Color.secondary_color)
                                .cornerRadius(8)
                                
                                if viewModel.showCalculator {
                                    CalculatorView(amountText: $viewModel.amount) {
                                        withAnimation {
                                            viewModel.showCalculator = false
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            
                            // Transaction Type Picker Button
                            Button(action: { viewModel.showTypeDrop = true }) {
                                HStack {
                                    Image(systemName: viewModel.selectedType == TRANS_TYPE_INCOME ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(viewModel.selectedType == TRANS_TYPE_INCOME ? Color.main_green : Color.main_red)
                                        .padding(.leading, 16)
                                    TextView(text: "Type", type: .button)
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text(viewModel.typeTitle)
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(viewModel.selectedType == TRANS_TYPE_INCOME ? Color.main_green : Color.main_red)
                                        .padding(.trailing, 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.text_secondary_color)
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color)
                            .cornerRadius(8)
                            .actionSheet(isPresented: $viewModel.showTypeDrop) {
                                ActionSheet(title: Text("Select Transaction Type"), buttons: [
                                    .default(Text("Income")) {
                                        viewModel.typeTitle = "Income"
                                        viewModel.selectedType = TRANS_TYPE_INCOME
                                    },
                                    .default(Text("Expense")) {
                                        viewModel.typeTitle = "Expense"
                                        viewModel.selectedType = TRANS_TYPE_EXPENSE
                                    },
                                    .cancel()
                                ])
                            }
                            
                            // Category (Tag) Picker Button
                            Button(action: { viewModel.showTagDrop = true }) {
                                HStack {
                                    Image(getTransTagIcon(transTag: viewModel.selectedTag))
                                        .resizable().scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .padding(.leading, 16)
                                    TextView(text: "Category", type: .button)
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text(viewModel.tagTitle)
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(Color.text_primary_color)
                                        .padding(.trailing, 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.text_secondary_color)
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color)
                            .cornerRadius(8)
                            .actionSheet(isPresented: $viewModel.showTagDrop) {
                                var buttons: [ActionSheet.Button] = tagOptions.map { option in
                                    .default(Text(option.val)) {
                                        viewModel.tagTitle = option.val
                                        viewModel.selectedTag = option.key
                                    }
                                }
                                buttons.append(.cancel())
                                return ActionSheet(title: Text("Select Category"), buttons: buttons)
                            }
                            
                            // Currency picker row
                            Button(action: { viewModel.showCurrencyPicker = true }) {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.main_color)
                                        .padding(.leading, 16)
                                    TextView(text: "Currency", type: .button)
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text(viewModel.currencyDisplayLabel)
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(Color.main_color)
                                        .padding(.trailing, 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.text_secondary_color)
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color)
                            .cornerRadius(8)
                            .actionSheet(isPresented: $viewModel.showCurrencyPicker) {
                                var buttons: [ActionSheet.Button] = SUPPORTED_CURRENCIES.map { curr in
                                    .default(Text(curr.displayLabel)) { viewModel.selectedCurrencyCode = curr.code }
                                }
                                buttons.append(.cancel())
                                return ActionSheet(title: Text("Transaction Currency"), message: Text("Select the currency this amount is in"), buttons: buttons)
                            }
                            
                            // Date picker
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.main_color)
                                    .padding(.leading, 16)
                                DatePicker("Date & Time", selection: $viewModel.occuredOn,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .accentColor(Color.main_color)
                                    .padding(.trailing, 16)
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color).cornerRadius(8)
                            
                            // Note
                            TextField("Note", text: $viewModel.note)
                                .modifier(InterFont(.regular, size: 16))
                                .accentColor(Color.text_primary_color)
                                .frame(height: 50).padding(.leading, 16)
                                .background(Color.secondary_color)
                                .cornerRadius(8)
                            
                            // Attachment
                            Button(action: { viewModel.attachImage() }) {
                                HStack {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 18.0, weight: .bold))
                                        .foregroundColor(Color.text_secondary_color)
                                        .padding(.leading, 16)
                                    TextView(text: "Attach an image", type: .button).foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                }
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color)
                            .cornerRadius(8)
                            .actionSheet(isPresented: $showAttachSheet) {
                                ActionSheet(title: Text("Do you want to remove the attachment?"), buttons: [
                                    .default(Text("Remove")) { viewModel.removeImage() },
                                    .cancel()
                                ])
                            }
                            
                            if let image = viewModel.imageAttached {
                                Button(action: { showAttachSheet = true }) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200).frame(maxWidth: .infinity)
                                        .background(Color.secondary_color)
                                        .cornerRadius(8)
                                        .clipped()
                                }
                            }
                            
                            // Ample bottom spacing so content never gets blocked by the sticky save button
                            Spacer().frame(height: 140)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .alert(isPresented: $viewModel.showAlert) {
                            Alert(title: Text(APP_NAME), message: Text(viewModel.alertMsg), dismissButton: .default(Text("OK")))
                        }
                    }
                }
                .edgesIgnoringSafeArea(.top)
                
                // Sticky Save Button at Bottom
                VStack {
                    Spacer()
                    Button(action: { viewModel.saveTransaction(managedObjectContext: managedObjectContext) }) {
                        HStack {
                            Spacer()
                            TextView(text: viewModel.getButtText(), type: .button).foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 14)
                    .background(Color.main_color)
                    .cornerRadius(12)
                    .shadow(color: Color.main_color.opacity(0.4), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .dismissKeyboardOnTap()
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onReceive(viewModel.$closePresenter) { close in
            if close { self.presentationMode.wrappedValue.dismiss() }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
}
