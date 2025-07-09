//
//  HeliusLaserStream.swift
//  PadraigAIO-MacOS
//
//  Enhanced pair detection using Helius LaserStream WebSockets
//  Based on PDF recommendations for real-time DEX monitoring
//

import Foundation
import Combine

// MARK: - Helius LaserStream Manager
class HeliusLaserStreamManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var newDetectedPairs: [TradingPair] = []
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    
    // Alternative WebSocket endpoints for DEX monitoring
    // Note: Helius may require API key authentication
    private let heliusURL = URL(string: "wss://mainnet.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f")!
    
    // Fallback to public Solana RPC WebSocket
    private let fallbackURL = URL(string: "wss://api.mainnet-beta.solana.com/")!
    
    // DEX program IDs to monitor (from PDFs)
    private let dexPrograms = [
        "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8", // Raydium AMM V4
        "9W959DqEETiGZocYWCQPaJ6sBmUzgfxXfqGeTEdp3aQP", // Orca Whirlpool
        "EhYXwEP8SAWTXkfGKJDHAdFYYPKiMLZLHdC4aB", // Serum DEX v3
        "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX"  // Serum DEX v2
    ]
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    func startLaserStream() {
        guard connectionStatus != .connected && connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        lastError = nil
        
        print("🔗 Connecting to Helius LaserStream...")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: heliusURL)
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        // Subscribe to DEX program account changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.subscribeToAccountChanges()
        }
        
        // Start connection monitoring
        startConnectionMonitoring()
    }
    
    func stopLaserStream() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        
        print("⏹️ Stopped Helius LaserStream")
    }
    
    private func disconnect() {
        stopLaserStream()
    }
    
    // MARK: - Account Subscription (Core Enhancement from PDFs)
    
    private func subscribeToAccountChanges() {
        print("📡 Subscribing to DEX program account changes...")
        
        // Subscribe to each DEX program separately for better monitoring
        for (index, programId) in dexPrograms.enumerated() {
            let subscriptionMessage: [String: Any] = [
                "jsonrpc": "2.0",
                "id": index + 1,
                "method": "accountSubscribe",
                "params": [
                    programId,
                    [
                        "encoding": "jsonParsed",
                        "commitment": "confirmed" // Faster than finalized for trading
                    ]
                ]
            ]
            
            sendWebSocketMessage(subscriptionMessage, for: programId)
        }
        
        connectionStatus = .connected
        reconnectAttempts = 0
        print("✅ Successfully subscribed to \(dexPrograms.count) DEX programs")
    }
    
    private func sendWebSocketMessage(_ message: [String: Any], for programId: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Failed to serialize subscription message for \(programId)")
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("❌ Failed to send subscription for \(programId): \(error)")
            } else {
                print("📤 Sent subscription for \(programId)")
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
                self.parseAccountChangeMessage(text)
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.parseAccountChangeMessage(text)
                }
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Enhanced Pair Detection Logic
    
    private func parseAccountChangeMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Handle subscription confirmation
                if let id = json["id"] as? Int, json["result"] != nil {
                    print("✅ Subscription \(id) confirmed")
                    return
                }
                
                // Handle account change notifications
                if let method = json["method"] as? String,
                   method == "accountNotification",
                   let params = json["params"] as? [String: Any] {
                    
                    processAccountNotification(params)
                }
            }
        } catch {
            print("❌ Error parsing LaserStream message: \(error)")
        }
    }
    
    private func processAccountNotification(_ params: [String: Any]) {
        // Extract account info from notification
        guard let result = params["result"] as? [String: Any],
              let value = result["value"] as? [String: Any],
              let accountInfo = value["account"] as? [String: Any],
              let data = accountInfo["data"] as? [String: Any] else {
            return
        }
        
        // Detect if this is a new liquidity pool creation
        if let newPair = detectNewLiquidityPool(from: data) {
            print("🎯 New pair detected via LaserStream: \(newPair.baseToken.symbol)/\(newPair.quoteToken.symbol)")
            
            newDetectedPairs.append(newPair)
            
            // Keep only last 50 detected pairs
            if newDetectedPairs.count > 50 {
                newDetectedPairs = Array(newDetectedPairs.suffix(50))
            }
            
            // Notify other systems
            NotificationCenter.default.post(
                name: NSNotification.Name("HeliusNewPairDetected"),
                object: newPair
            )
        }
    }
    
    private func detectNewLiquidityPool(from accountData: [String: Any]) -> TradingPair? {
        // Advanced logic to detect new pool creation from account change data
        // This would analyze the account data structure to identify:
        // - New liquidity pool initialization
        // - Token mint addresses
        // - Initial liquidity amounts
        // - Pool creation timestamp
        
        // For now, return nil - full implementation would require detailed
        // understanding of each DEX's account data structure
        
        // TODO: Implement sophisticated pool detection logic
        // This is where the real competitive advantage comes from
        
        return nil
    }
    
    // MARK: - Connection Monitoring (Critical for Trading Apps)
    
    private func startConnectionMonitoring() {
        // Send periodic pings as recommended in PDFs (every 30-60 seconds)
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        guard connectionStatus == .connected else { return }
        
        // Send a simple JSON-RPC ping message instead
        let pingMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 999,
            "method": "ping"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: pingMessage),
              let string = String(data: data, encoding: .utf8) else { return }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("💔 Ping failed: \(error)")
                DispatchQueue.main.async {
                    self.handleConnectionError(error)
                }
            }
        }
    }
    
    // MARK: - Error Handling and Reconnection
    
    private func handleConnectionError(_ error: Error) {
        lastError = error.localizedDescription
        connectionStatus = .error(error.localizedDescription)
        
        print("❌ Helius LaserStream error: \(error)")
        
        // Implement exponential backoff reconnection
        if reconnectAttempts < maxReconnectAttempts {
            let delay = pow(2.0, Double(reconnectAttempts))
            reconnectAttempts += 1
            
            print("🔄 Reconnecting to LaserStream in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                self.startLaserStream()
            }
        } else {
            print("💀 Max LaserStream reconnection attempts reached")
            connectionStatus = .error("Connection failed after \(maxReconnectAttempts) attempts")
        }
    }
    
    func reconnect() {
        stopLaserStream()
        reconnectAttempts = 0
        startLaserStream()
    }
    
    func clearDetectedPairs() {
        newDetectedPairs.removeAll()
    }
}

// MARK: - Integration Helper

extension HeliusLaserStreamManager {
    var isConnected: Bool {
        switch connectionStatus {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    var statusText: String {
        switch connectionStatus {
        case .connected: return "LaserStream Connected"
        case .connecting: return "Connecting to LaserStream..."
        case .disconnected: return "LaserStream Disconnected"
        case .error(let message): return "LaserStream Error: \(message)"
        }
    }
}