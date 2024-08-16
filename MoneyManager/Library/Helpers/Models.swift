//
//  Models.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import UIKit
import SwiftUI

// Lazy Navigation to load (constructor) after clicked on Button
struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
    var body: Content { build() }
}

struct ToolbarModelView: View {
    
    var title: String
    var hasBackButt: Bool = true
    var button1Icon: String?
    var button2Icon: String?
    
    var backButtonClick: () -> ()
    var button1Method: (() -> ())?
    var button2Method: (() -> ())?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            if hasBackButt {
                Button(action: { self.backButtonClick() }) {
                    Image("back_arrow")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 28.0, height: 28.0)
                        .foregroundColor(Color.text_primary_color)
                }
            }
            
            TextView(text: title, type: .h6)
                .foregroundColor(Color.text_primary_color)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            HStack(spacing: 12) {
                if let button2Method = self.button2Method {
                    Button(action: { button2Method() }) {
                        Image(button2Icon ?? "")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundColor(Color.text_primary_color)
                    }
                }
                if let button1Method = self.button1Method {
                    Button(action: { button1Method() }) {
                        Image(button1Icon ?? "")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24.0, height: 24.0)
                            .foregroundColor(Color.text_primary_color)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .padding(.top, 24)
        .background(Color.secondary_color)
    }
}

 
 
 
