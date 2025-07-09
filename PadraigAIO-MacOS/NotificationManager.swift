//
//  NotificationManager.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Notification Types
enum NotificationType {
    case success
    case error
    case warning
    case info
    case tokenMatch
    case snipeSuccess
    case snipeFailure
    case connectionStatus
}

struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let autoHide: Bool
    let duration: TimeInterval
    
    init(type: NotificationType, title: String, message: String, autoHide: Bool = true, duration: TimeInterval = 5.0) {
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = Date()
        self.autoHide = autoHide
        self.duration = duration
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    @Published var activeNotifications: [AppNotification] = []
    @Published var showToast = false
    
    static let shared = NotificationManager()
    
    private init() {
        setupSystemNotifications()
    }
    
    private func setupSystemNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if error != nil {
                print("Notification permission error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Public Interface
    func show(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.activeNotifications.append(notification)
            self.showToast = true
            
            if notification.autoHide {
                DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
                    self.hide(notification)
                }
            }
        }
    }
    
    func hide(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.activeNotifications.removeAll { $0.id == notification.id }
        }
    }
    
    func hideAll() {
        DispatchQueue.main.async {
            self.activeNotifications.removeAll()
            self.showToast = false
        }
    }
    
    // MARK: - Convenience Methods
    func success(_ title: String, _ message: String = "") {
        let notification = AppNotification(
            type: .success,
            title: title,
            message: message
        )
        show(notification)
    }
    
    func error(_ title: String, _ message: String = "") {
        let notification = AppNotification(
            type: .error,
            title: title,
            message: message,
            autoHide: false
        )
        show(notification)
        sendSystemNotification(title: "Error: \\(title)", body: message)
    }
    
    func warning(_ title: String, _ message: String = "") {
        let notification = AppNotification(
            type: .warning,
            title: title,
            message: message,
            duration: 7.0
        )
        show(notification)
    }
    
    func info(_ title: String, _ message: String = "") {
        let notification = AppNotification(
            type: .info,
            title: title,
            message: message
        )
        show(notification)
    }
    
    func tokenMatch(_ tokenName: String, _ reason: String) {
        let notification = AppNotification(
            type: .tokenMatch,
            title: "Token Match Found",
            message: "\\(tokenName): \\(reason)",
            autoHide: false
        )
        show(notification)
        sendSystemNotification(title: "🎯 Token Match: \\(tokenName)", body: reason)
    }
    
    func snipeSuccess(_ tokenName: String, _ signature: String) {
        let notification = AppNotification(
            type: .snipeSuccess,
            title: "Snipe Successful",
            message: "\\(tokenName) purchased successfully",
            duration: 10.0
        )
        show(notification)
        sendSystemNotification(title: "✅ Snipe Success: \\(tokenName)", body: "Transaction: \\(signature.prefix(8))...")
    }
    
    func snipeFailure(_ tokenName: String, _ error: String) {
        let notification = AppNotification(
            type: .snipeFailure,
            title: "Snipe Failed",
            message: "\\(tokenName): \\(error)",
            autoHide: false
        )
        show(notification)
        sendSystemNotification(title: "❌ Snipe Failed: \\(tokenName)", body: error)
    }
    
    func connectionStatus(_ status: String, isConnected: Bool) {
        let notification = AppNotification(
            type: .connectionStatus,
            title: isConnected ? "Connected" : "Disconnected",
            message: status,
            duration: 3.0
        )
        show(notification)
        
        if !isConnected {
            sendSystemNotification(title: "Connection Lost", body: status)
        }
    }
    
    // MARK: - System Notifications
    private func sendSystemNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                print("System notification error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}

// MARK: - Error Handler
class ErrorHandler: ObservableObject {
    @Published var lastError: AppError?
    
    static let shared = ErrorHandler()
    private let notificationManager = NotificationManager.shared
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        let appError = AppError(error: error, context: context)
        
        DispatchQueue.main.async {
            self.lastError = appError
        }
        
        // Show notification
        let title = context.isEmpty ? "Error" : "\(context) Error"
        notificationManager.error(title, appError.localizedDescription)
        
        // Log error
        print("🚨 ERROR [\(context)]: \(appError.localizedDescription)")
        if appError.underlyingError != nil {
            print("   Underlying: \(appError.underlyingError?.localizedDescription ?? "Unknown underlying error")")
        }
    }
    
    func handleWalletError(_ error: WalletError, operation: String) {
        let appError = AppError(
            message: "Wallet operation failed",
            context: operation,
            underlyingError: error
        )
        
        DispatchQueue.main.async {
            self.lastError = appError
        }
        
        notificationManager.error("Wallet \\(operation) Failed", error.localizedDescription)
    }
    
    func handleTransactionError(_ error: String, tokenName: String) {
        let appError = AppError(
            message: error,
            context: "Transaction for \\(tokenName)"
        )
        
        DispatchQueue.main.async {
            self.lastError = appError
        }
        
        notificationManager.snipeFailure(tokenName, error)
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.lastError = nil
        }
    }
}

// MARK: - App Error
struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let message: String
    let context: String
    let timestamp = Date()
    let underlyingError: Error?
    
    init(error: Error, context: String = "") {
        self.message = error.localizedDescription
        self.context = context
        self.underlyingError = error
    }
    
    init(message: String, context: String = "", underlyingError: Error? = nil) {
        self.message = message
        self.context = context
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        if context.isEmpty {
            return message
        } else {
            return "\\(context): \\(message)"
        }
    }
    
    var fullDescription: String {
        var description = errorDescription ?? "Unknown error"
        if underlyingError != nil {
            description += " (\(underlyingError?.localizedDescription ?? "Unknown underlying error"))"
        }
        return description
    }
}

// MARK: - Toast View
struct ToastView: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(PadraigTheme.primaryText)
                
                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(PadraigTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(PadraigTheme.secondaryText)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var iconName: String {
        switch notification.type {
        case .success, .snipeSuccess:
            return "checkmark.circle.fill"
        case .error, .snipeFailure:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .tokenMatch:
            return "target"
        case .connectionStatus:
            return "wifi"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .success, .snipeSuccess:
            return .padraigTeal
        case .error, .snipeFailure:
            return .padraigRed
        case .warning:
            return .padraigOrange
        case .info, .connectionStatus:
            return .padraigTeal
        case .tokenMatch:
            return .padraigOrange
        }
    }
    
    private var backgroundColor: Color {
        switch notification.type {
        case .success, .snipeSuccess:
            return Color.padraigTeal.opacity(0.1)
        case .error, .snipeFailure:
            return Color.padraigRed.opacity(0.1)
        case .warning:
            return Color.padraigOrange.opacity(0.1)
        case .info, .connectionStatus:
            return Color.padraigTeal.opacity(0.1)
        case .tokenMatch:
            return Color.padraigOrange.opacity(0.1)
        }
    }
}

// MARK: - Toast Container
struct ToastContainer: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.activeNotifications) { notification in
                ToastView(notification: notification) {
                    notificationManager.hide(notification)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: notificationManager.activeNotifications)
    }
}