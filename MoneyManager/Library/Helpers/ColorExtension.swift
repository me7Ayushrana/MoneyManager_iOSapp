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
    
    static var main_color: Color {
        isDarkModeEnabled ? Color(hex: "3B82F6") : Color(hex: "2563EB")
    }
    
    static var primary_color: Color {
        isDarkModeEnabled ? Color(hex: "0B0F19") : Color(hex: "F3F4F6")
    }
    
    static var secondary_color: Color {
        isDarkModeEnabled ? Color(hex: "151D30") : Color(hex: "FFFFFF")
    }
    
    static var text_primary_color: Color {
        isDarkModeEnabled ? Color(hex: "F3F4F6") : Color(hex: "111827")
    }
    
    static var text_secondary_color: Color {
        isDarkModeEnabled ? Color(hex: "9CA3AF") : Color(hex: "4B5563")
    }
    
    static var placeholder_color: Color {
        isDarkModeEnabled ? Color(hex: "4B5563") : Color(hex: "9CA3AF")
    }
    
    static var main_green: Color {
        isDarkModeEnabled ? Color(hex: "10B981") : Color(hex: "059669")
    }
    
    static var main_red: Color {
        isDarkModeEnabled ? Color(hex: "EF4444") : Color(hex: "DC2626")
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
        self.init(.sRGB, red: Double(r) / 0xff, green: Double(g) / 0xff, blue:  Double(b) / 0xff, opacity: alpha)
    }
}

extension UIColor {
    
    static var isDarkModeEnabled: Bool {
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    static var primary_color: UIColor {
        isDarkModeEnabled ? UIColor(hex: "0B0F19") : UIColor(hex: "F3F4F6")
    }
    
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexFormatted: String = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
        
        if hexFormatted.hasPrefix("#") {
            hexFormatted = String(hexFormatted.dropFirst())
        }
        
        assert(hexFormatted.count == 6, "Invalid hex code used.")
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: alpha)
    }
}
 
 
 
