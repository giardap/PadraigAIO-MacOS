//
//  ContentView.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ModernContentView()
            .background(PadraigTheme.primaryBackground)
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Wallet.self, inMemory: true)
}