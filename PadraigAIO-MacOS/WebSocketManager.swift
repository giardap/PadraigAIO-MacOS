//
//  WebSocketManager.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import Combine

// MARK: - WebSocket Manager for PumpPortal
class PumpPortalWebSocketManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var newTokens: [TokenCreation] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    private let pumpPortalURL = URL(string: "wss://pumpportal.fun/api/data")!
    
    init() {
        // Don't auto-connect on init
        // User will manually start the feed
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    func connect() {
        guard connectionStatus != .connected && connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        lastError = nil
        
        print("Attempting to connect to: \(pumpPortalURL.absoluteString)")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: pumpPortalURL)
        
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        // Check connection status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.connectionStatus == .connecting {
                print("Connection timeout - still connecting after 5 seconds")
                self.connectionStatus = .error("Connection timeout")
            }
        }
        
        // Send subscription message for new token events
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.subscribeToNewTokens()
        }
        
        // Monitor connection
        monitorConnection()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func subscribeToNewTokens() {
        let subscriptionMessage: [String: Any] = [
            "method": "subscribeNewToken",
            "keys": ["*"] // Subscribe to all new tokens
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: subscriptionMessage),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if error != nil {
                print("Error sending subscription: \(error?.localizedDescription ?? "Unknown error")")
            } else {
                DispatchQueue.main.async {
                    self.connectionStatus = .connected
                    self.reconnectAttempts = 0
                    print("Successfully subscribed to PumpPortal new token events")
                }
            }
        }
    }
    
    // MARK: - Message Handling
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.handleConnectionError(error)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            DispatchQueue.main.async {
                self.parseTokenMessage(text)
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.parseTokenMessage(text)
                }
            }
        @unknown default:
            break
        }
    }
    
    private func parseTokenMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            // Debug: Print raw JSON to see what fields are available
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔍 RAW WEBSOCKET DATA:")
                for (key, value) in json {
                    print("   \(key): \(value)")
                }
                print("---")
            }
            
            // Try to parse as token creation event
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let mint = json["mint"] as? String,
               let name = json["name"] as? String,
               let symbol = json["symbol"] as? String {
                
                // Extract all possible image/metadata fields
                let image = json["image"] as? String
                let imageUri = json["imageUri"] as? String
                let imageUrl = json["imageUrl"] as? String
                let logoUri = json["logoUri"] as? String
                let logoUrl = json["logoUrl"] as? String
                let metadataUri = json["metadataUri"] as? String
                let metadataUrl = json["metadataUrl"] as? String
                let tokenUri = json["tokenUri"] as? String
                let uri = json["uri"] as? String
                
                // Use the first available image field
                let finalImageUrl = image ?? imageUri ?? imageUrl ?? logoUri ?? logoUrl
                
                print("🖼️ IMAGE FIELDS FOUND:")
                print("   image: \(image ?? "nil")")
                print("   imageUri: \(imageUri ?? "nil")")
                print("   imageUrl: \(imageUrl ?? "nil")")
                print("   logoUri: \(logoUri ?? "nil")")
                print("   logoUrl: \(logoUrl ?? "nil")")
                print("   FINAL IMAGE: \(finalImageUrl ?? "nil")")
                
                print("📋 METADATA FIELDS FOUND:")
                print("   metadataUri: \(metadataUri ?? "nil")")
                print("   metadataUrl: \(metadataUrl ?? "nil")")
                print("   tokenUri: \(tokenUri ?? "nil")")
                print("   uri: \(uri ?? "nil")")
                
                // Extract possible social/website fields
                let website = json["website"] as? String
                let twitter = json["twitter"] as? String
                let telegram = json["telegram"] as? String
                let discord = json["discord"] as? String
                let externalUrl = json["external_url"] as? String
                let externalLink = json["external_link"] as? String
                let socialLinks = json["social_links"] as? [String]
                let links = json["links"] as? [String: Any]
                
                print("🔗 SOCIAL/WEBSITE FIELDS FOUND:")
                print("   website: \(website ?? "nil")")
                print("   twitter: \(twitter ?? "nil")")
                print("   telegram: \(telegram ?? "nil")")
                print("   discord: \(discord ?? "nil")")
                print("   external_url: \(externalUrl ?? "nil")")
                print("   external_link: \(externalLink ?? "nil")")
                print("   social_links: \(socialLinks ?? [])")
                print("   links: \(links ?? [:])")
                
                // Extract pump.fun specific data
                let vSolInBondingCurve = json["vSolInBondingCurve"] as? Double
                let vTokensInBondingCurve = json["vTokensInBondingCurve"] as? Double
                let marketCapSol = json["marketCapSol"] as? Double
                let solAmount = json["solAmount"] as? Double
                let initialBuy = json["initialBuy"] as? Double
                let traderPublicKey = json["traderPublicKey"] as? String
                
                print("🔢 PUMP.FUN FINANCIAL DATA:")
                print("   vSolInBondingCurve: \(vSolInBondingCurve ?? 0)")
                print("   vTokensInBondingCurve: \(vTokensInBondingCurve ?? 0)")
                print("   marketCapSol: \(marketCapSol ?? 0)")
                print("   solAmount: \(solAmount ?? 0)")
                print("   initialBuy: \(initialBuy ?? 0)")
                print("   traderPublicKey: \(traderPublicKey ?? "nil")")
                
                // Collect all possible social links from WebSocket data
                var webSocketSocialLinks: [String] = []
                if let website = website { webSocketSocialLinks.append(website) }
                if let twitter = twitter { webSocketSocialLinks.append(twitter) }
                if let telegram = telegram { webSocketSocialLinks.append(telegram) }
                if let discord = discord { webSocketSocialLinks.append(discord) }
                if let externalUrl = externalUrl { webSocketSocialLinks.append(externalUrl) }
                if let externalLink = externalLink { webSocketSocialLinks.append(externalLink) }
                if let socialLinks = socialLinks { webSocketSocialLinks.append(contentsOf: socialLinks) }
                if let links = links {
                    for (_, value) in links {
                        if let urlString = value as? String {
                            webSocketSocialLinks.append(urlString)
                        }
                    }
                }
                
                print("🌐 COLLECTED WEBSOCKET SOCIAL LINKS: \(webSocketSocialLinks)")
                
                let tokenCreation = TokenCreation(
                    mint: mint,
                    name: name,
                    symbol: symbol,
                    description: json["description"] as? String,
                    image: finalImageUrl,
                    createdTimestamp: json["createdTimestamp"] as? TimeInterval ?? Date().timeIntervalSince1970 * 1000,
                    creator: json["creator"] as? String ?? traderPublicKey,
                    totalSupply: vTokensInBondingCurve,
                    initialLiquidity: vSolInBondingCurve,
                    raydiumPool: json["raydiumPool"] as? String,
                    complete: json["complete"] as? Bool,
                    metadataUri: metadataUri ?? metadataUrl ?? tokenUri ?? uri,
                    webSocketSocialLinks: webSocketSocialLinks, // Add WebSocket social links
                    // Add pump.fun specific fields
                    marketCapSol: marketCapSol,
                    solAmount: solAmount,
                    initialBuy: initialBuy,
                    vSolInBondingCurve: vSolInBondingCurve,
                    vTokensInBondingCurve: vTokensInBondingCurve
                )
                
                self.newTokens.append(tokenCreation)
                // Keep only last 100 tokens to prevent memory issues
                if self.newTokens.count > 100 {
                    self.newTokens.removeFirst(self.newTokens.count - 100)
                }
                
                // Post notification for sniper to process
                print("🔔 WebSocket posting NewTokenCreated notification for: \(tokenCreation.name) (\(tokenCreation.symbol))")
                print("   Description: \(tokenCreation.description ?? "None")")
                print("   Image URL: \(tokenCreation.image ?? "None")")
                if let metaUri = tokenCreation.metadataUri {
                    print("   Metadata URI: \(metaUri)")
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewTokenCreated"),
                    object: tokenCreation
                )
            }
        } catch {
            print("Error parsing token message: \(error)")
        }
    }
    
    // MARK: - Error Handling and Reconnection
    private func handleConnectionError(_ error: Error) {
        lastError = error.localizedDescription
        connectionStatus = .error(error.localizedDescription)
        
        print("WebSocket error: \\(error)")
        
        // Attempt reconnection with exponential backoff
        if reconnectAttempts < maxReconnectAttempts {
            let delay = pow(2.0, Double(reconnectAttempts)) // Exponential backoff
            reconnectAttempts += 1
            
            print("Reconnecting in \\(delay) seconds (attempt \\(reconnectAttempts)/\\(maxReconnectAttempts))")
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                self.connect()
            }
        } else {
            print("Max reconnection attempts reached")
            connectionStatus = .error("Connection failed after \\(maxReconnectAttempts) attempts")
        }
    }
    
    private func monitorConnection() {
        // Send ping every 30 seconds to keep connection alive
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] timer in
            guard let self = self,
                  self.connectionStatus == .connected,
                  let webSocketTask = self.webSocketTask else {
                timer.invalidate()
                return
            }
            
            let ping = URLSessionWebSocketTask.Message.string("{\"method\":\"ping\"}")
            webSocketTask.send(ping) { error in
                if let error = error {
                    print("Ping failed: \\(error)")
                    DispatchQueue.main.async {
                        self.handleConnectionError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Public Interface
    func startTokenFeed() {
        connect()
        // Mock data generation disabled - using real API data only
        // startMockDataGeneration()
    }
    
    func stopTokenFeed() {
        disconnect()
        // stopMockDataGeneration()
    }
    
    func reconnect() {
        disconnect()
        reconnectAttempts = 0
        connect()
    }
    
    func clearTokenHistory() {
        newTokens.removeAll()
    }
    
    var isConnected: Bool {
        switch connectionStatus {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Mock Data Generation (DISABLED)
    // Mock data generation has been completely disabled
    // The application now uses only real API data from:
    // - DexScreener API for established token pairs
    // - Pump.fun WebSocket feed for new token creation events
    // - Helius API for enhanced blockchain monitoring
    // - Direct Solana RPC for real-time blockchain events
}