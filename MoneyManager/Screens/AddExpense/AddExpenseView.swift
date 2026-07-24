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
        DropdownOption(key: TRANS_TAG_OTHERS, val: "Others"),
        DropdownOption(key: TRANS_TAG_UTILITIES, val: "Utilities")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack {
                    
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
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            
                            // Title
                            TextField("Title", text: $viewModel.title)
                                .modifier(InterFont(.regular, size: 16))
                                .accentColor(Color.text_primary_color)
                                .frame(height: 50).padding(.leading, 16)
                                .background(Color.secondary_color)
                                .cornerRadius(4)
                            
                            // Amount + currency symbol prefix
                            HStack(spacing: 0) {
                                // Symbol badge
                                Text(symbolFor(currencyCode: viewModel.selectedCurrencyCode))
                                    .modifier(InterFont(.semiBold, size: 18))
                                    .foregroundColor(Color.main_color)
                                    .frame(width: 44, height: 50)
                                    .background(Color.main_color.opacity(0.12))
                                
                                TextField("Amount", text: $viewModel.amount)
                                    .modifier(InterFont(.regular, size: 16))
                                    .accentColor(Color.text_primary_color)
                                    .frame(height: 50).padding(.leading, 12)
                                    .keyboardType(.decimalPad)
                            }
                            .background(Color.secondary_color)
                            .cornerRadius(4)
                            
                            // Currency picker row
                            Button(action: { viewModel.showCurrencyPicker = true }) {
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color.main_color)
                                        .padding(.leading, 16)
                                    TextView(text: "Transaction Currency", type: .button)
                                        .foregroundColor(Color.text_secondary_color)
                                    Spacer()
                                    Text(viewModel.currencyDisplayLabel)
                                        .modifier(InterFont(.semiBold, size: 14))
                                        .foregroundColor(Color.main_color)
                                        .padding(.trailing, 12)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.text_secondary_color)
                                        .padding(.trailing, 16)
                                }
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .background(Color.secondary_color)
                            .cornerRadius(4)
                            .actionSheet(isPresented: $viewModel.showCurrencyPicker) {
                                var buttons: [ActionSheet.Button] = SUPPORTED_CURRENCIES.map { curr in
                                    .default(Text(curr.displayLabel)) { viewModel.selectedCurrencyCode = curr.code }
                                }
                                buttons.append(.cancel())
                                return ActionSheet(title: Text("Transaction Currency"), message: Text("Select the currency this amount is in"), buttons: buttons)
                            }
                            
                            // Type dropdown
                            DropdownButton(shouldShowDropdown: $viewModel.showTypeDrop,
                                           displayText: $viewModel.typeTitle,
                                           options: typeOptions,
                                           mainColor: Color.text_primary_color,
                                           backgroundColor: Color.secondary_color,
                                           cornerRadius: 4, buttonHeight: 50) { key in
                                let selected = typeOptions.first { $0.key == key }
                                if let object = selected {
                                    viewModel.typeTitle = object.val
                                    viewModel.selectedType = key
                                }
                                viewModel.showTypeDrop = false
                            }
                            
                            // Tag dropdown
                            DropdownButton(shouldShowDropdown: $viewModel.showTagDrop,
                                           displayText: $viewModel.tagTitle,
                                           options: tagOptions,
                                           mainColor: Color.text_primary_color,
                                           backgroundColor: Color.secondary_color,
                                           cornerRadius: 4, buttonHeight: 50) { key in
                                let selected = tagOptions.first { $0.key == key }
                                if let object = selected {
                                    viewModel.tagTitle = object.val
                                    viewModel.selectedTag = key
                                }
                                viewModel.showTagDrop = false
                            }
                            
                            // Date picker
                            HStack {
                                DatePicker("PickerView", selection: $viewModel.occuredOn,
                                           displayedComponents: [.date, .hourAndMinute]).labelsHidden().padding(.leading, 16)
                                Spacer()
                            }
                            .frame(height: 50).frame(maxWidth: .infinity)
                            .accentColor(Color.text_primary_color)
                            .background(Color.secondary_color).cornerRadius(4)
                            
                            // Note
                            TextField("Note", text: $viewModel.note)
                                .modifier(InterFont(.regular, size: 16))
                                .accentColor(Color.text_primary_color)
                                .frame(height: 50).padding(.leading, 16)
                                .background(Color.secondary_color)
                                .cornerRadius(4)
                            
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
                            .cornerRadius(4)
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
                                        .frame(height: 250).frame(maxWidth: .infinity)
                                        .background(Color.secondary_color)
                                        .cornerRadius(4)
                                }
                            }
                            
                            Spacer().frame(height: 150)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity).padding(.horizontal, 8)
                        .alert(isPresented: $viewModel.showAlert,
                               content: { Alert(title: Text(APP_NAME), message: Text(viewModel.alertMsg), dismissButton: .default(Text("OK"))) })
                    }
                    
                }.edgesIgnoringSafeArea(.top)
                
                // Save button
                VStack {
                    Spacer()
                    VStack {
                        Button(action: { viewModel.saveTransaction(managedObjectContext: managedObjectContext) }) {
                            HStack {
                                Spacer()
                                TextView(text: viewModel.getButtText(), type: .button).foregroundColor(.white)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 12).background(Color.main_color).cornerRadius(8)
                    }.padding(.bottom, 16).padding(.horizontal, 8)
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
