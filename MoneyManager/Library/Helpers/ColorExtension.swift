//
//  ColorExtension.swift
//  MoneyManager
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

extension Color {
    
    static var isDarkModeEnabled: Bool {
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    // Fintech Palette Tokens
    static var main_color: Color {
        isDarkModeEnabled ? Color(hex: "3B82F6") : Color(hex: "2563EB")
    }
    
    static var secondary_accent: Color {
        isDarkModeEnabled ? Color(hex: "818CF8") : Color(hex: "6D5EF7")
    }
    
    static var primary_color: Color {
        isDarkModeEnabled ? Color(hex: "0F1115") : Color(hex: "F7F9FC")
    }
    
    static var secondary_color: Color {
        isDarkModeEnabled ? Color(hex: "1A1D24") : Color(hex: "FFFFFF")
    }
    
    static var text_primary_color: Color {
        isDarkModeEnabled ? Color(hex: "F8FAFC") : Color(hex: "0F172A")
    }
    
    static var text_secondary_color: Color {
        isDarkModeEnabled ? Color(hex: "94A3B8") : Color(hex: "64748B")
    }
    
    static var placeholder_color: Color {
        isDarkModeEnabled ? Color(hex: "64748B") : Color(hex: "94A3B8")
    }
    
    static var main_green: Color {
        Color(hex: "10B981") // Emerald Success
    }
    
    static var main_red: Color {
        Color(hex: "EF4444") // Rose Error
    }
    
    static var card_border: Color {
        isDarkModeEnabled ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
    
    init(hex: String, alpha: Double = 1) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) { cString.remove(at: cString.startIndex) }
        
        let scanner = Scanner(string: cString)
        scanner.currentIndex = scanner.string.startIndex
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff
        
        self.init(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: alpha)
    }
}

extension UIColor {
    static var primary_color: UIColor {
        UIColor(Color.primary_color)
    }
    
    convenience init(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) { cString.remove(at: cString.startIndex) }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
