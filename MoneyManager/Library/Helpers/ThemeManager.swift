//
//  ThemeManager.swift
//  MoneyManager
//

import SwiftUI
import Combine

class ThemeManager: ObservableObject {

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            isDarkMode = true  // default: dark mode
        } else {
            isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
    }

    func toggle() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isDarkMode.toggle()
        }
    }
}
