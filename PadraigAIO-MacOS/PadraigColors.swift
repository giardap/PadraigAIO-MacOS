//
//  PadraigColors.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI

// MARK: - Padraig Brand Colors
extension Color {
    
    // Brand colors from the Padraig logo
    static let padraigRed = Color(red: 1.0, green: 0.267, blue: 0.267) // #FF4444
    static let padraigOrange = Color(red: 1.0, green: 0.647, blue: 0.0) // #FFA500  
    static let padraigTeal = Color(red: 0.0, green: 0.831, blue: 0.667) // #00D4AA
    static let padraigLightGray = Color(red: 0.94, green: 0.94, blue: 0.94) // #F0F0F0
    static let padraigDarkGray = Color(red: 0.2, green: 0.2, blue: 0.2) // #333333
    
    // Gradient combinations from logo
    static let padraigPrimaryGradient = LinearGradient(
        colors: [.padraigRed, .padraigOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let padraigSecondaryGradient = LinearGradient(
        colors: [.padraigOrange, .padraigTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let padraigAccentGradient = LinearGradient(
        colors: [.padraigTeal, .padraigRed],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Theme variants
    static let padraigSuccess = padraigTeal
    static let padraigWarning = padraigOrange
    static let padraigError = padraigRed
    static let padraigInfo = Color.blue
    
    // Background variations - darker for better contrast
    static let padraigBackground = Color(red: 0.12, green: 0.12, blue: 0.15) // Dark background
    static let padraigCardBackground = Color(red: 0.18, green: 0.18, blue: 0.22) // Dark card
    static let padraigSidebarBackground = Color(red: 0.15, green: 0.15, blue: 0.18) // Dark sidebar
}

// MARK: - Padraig Theme Manager
struct PadraigTheme {
    
    // Primary colors for different UI elements
    static let primaryAccent = Color.padraigRed
    static let secondaryAccent = Color.padraigOrange  
    static let tertiaryAccent = Color.padraigTeal
    
    // Status colors
    static let success = Color.padraigTeal
    static let warning = Color.padraigOrange
    static let error = Color.padraigRed
    
    // Background hierarchy
    static let primaryBackground = Color.padraigBackground
    static let secondaryBackground = Color.padraigCardBackground
    static let sidebarBackground = Color.padraigSidebarBackground
    
    // Text colors - high contrast for readability
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.8, green: 0.8, blue: 0.8)
    static let accentText = Color.padraigRed
}