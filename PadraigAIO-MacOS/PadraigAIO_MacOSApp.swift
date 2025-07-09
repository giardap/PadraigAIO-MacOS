//
//  PadraigAIO_MacOSApp.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import SwiftUI
import SwiftData

@main
struct PadraigAIO_MacOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Wallet.self,
            SniperConfig.self,
            TransactionRecord.self,
            SniperStats.self
        ])
        
        // For development: Clean slate approach - delete any existing problematic database
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupportURL.appendingPathComponent("default.store")
        
        // Remove existing database files to avoid migration issues during development
        let fileManager = FileManager.default
        let storeFiles = [
            storeURL,
            storeURL.appendingPathExtension("wal"),
            storeURL.appendingPathExtension("shm")
        ]
        
        for file in storeFiles {
            if fileManager.fileExists(atPath: file.path) {
                try? fileManager.removeItem(at: file)
                print("Removed existing database file: \(file.lastPathComponent)")
            }
        }
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1200, height: 800)
    }
}
