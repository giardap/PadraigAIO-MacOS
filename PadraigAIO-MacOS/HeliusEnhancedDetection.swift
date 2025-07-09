//
//  HeliusEnhancedDetection.swift
//  PadraigAIO-MacOS
//
//  Enhanced pair detection using Helius RPC and Enhanced APIs
//  Based on research of Helius capabilities for real-time token and DEX monitoring
//

import Foundation
import Combine

// MARK: - Helius Enhanced Detection Manager
class HeliusEnhancedDetectionManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var newTokensDetected: [TokenCreation] = []
    @Published var newPoolsDetected: [TradingPair] = []
    @Published var lastError: String?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    
    // Helius endpoints with API key
    private let heliusRPC = "https://mainnet.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f"
    private let heliusWS = "wss://mainnet.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f"
    private let heliusDAS = "https://mainnet.helius-rpc.com/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f"
    
    // Key Solana program addresses for monitoring
    private let monitoredPrograms = [
        "675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8", // Raydium AMM V4
        "9W959DqEETiGZocYWCQPaJ6sBmUzgfxXfqGeTEdp3aQP", // Orca Whirlpool
        "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",   // SPL Token Program
        "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"    // Token Metadata Program
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
    
    // MARK: - Enhanced Detection Methods
    
    func startEnhancedDetection() {
        guard connectionStatus != .connected && connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        lastError = nil
        
        print("🚀 Starting Helius Enhanced Detection...")
        
        // Start Geyser Enhanced WebSocket for real-time monitoring
        startGeyserWebSocket()
        
        // Start periodic polling for new tokens using enhanced methods
        startPeriodicTokenScanning()
        
        print("✅ Enhanced detection started: Geyser WebSocket + Enhanced RPC")
    }
    
    func stopEnhancedDetection() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionStatus = .disconnected
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
        
        print("⏹️ Stopped Helius Enhanced Detection")
    }
    
    private func disconnect() {
        stopEnhancedDetection()
    }
    
    // MARK: - Geyser Enhanced WebSocket (Business/Professional Plan Feature)
    
    private func startGeyserWebSocket() {
        guard let url = URL(string: heliusWS) else { return }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        // Subscribe to program accounts after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.subscribeToPrograms()
        }
        
        // Start connection monitoring
        startConnectionMonitoring()
    }
    
    private func subscribeToPrograms() {
        print("📡 Subscribing to Solana programs for enhanced detection...")
        
        // Subscribe to Raydium AMM for new pool creation
        subscribeToRaydiumPools()
        
        // Subscribe to Token Program for new token mints
        subscribeToTokenMints()
        
        connectionStatus = .connected
        reconnectAttempts = 0
        print("✅ Successfully subscribed to enhanced detection programs")
    }
    
    private func subscribeToRaydiumPools() {
        let raydiumSubscription: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "transactionSubscribe",
            "params": [
                [
                    "accountInclude": ["675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8"], // Raydium AMM
                    "commitment": "confirmed",
                    "encoding": "jsonParsed",
                    "transactionDetails": "full",
                    "maxSupportedTransactionVersion": 0
                ]
            ]
        ]
        
        sendWebSocketMessage(raydiumSubscription, for: "Raydium Pool Detection")
    }
    
    private func subscribeToTokenMints() {
        let tokenSubscription: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 2,
            "method": "transactionSubscribe",
            "params": [
                [
                    "accountInclude": ["TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"], // SPL Token Program
                    "commitment": "confirmed",
                    "encoding": "jsonParsed",
                    "transactionDetails": "full",
                    "maxSupportedTransactionVersion": 0
                ]
            ]
        ]
        
        sendWebSocketMessage(tokenSubscription, for: "Token Mint Detection")
    }
    
    private func sendWebSocketMessage(_ message: [String: Any], for description: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Failed to serialize subscription message for \(description)")
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("❌ Failed to send subscription for \(description): \(error)")
            } else {
                print("📤 Sent subscription for \(description)")
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
                self.parseTransactionMessage(text)
            }
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.parseTransactionMessage(text)
                }
            }
        @unknown default:
            break
        }
    }
    
    private func parseTransactionMessage(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Handle subscription confirmation
                if let id = json["id"] as? Int, json["result"] != nil {
                    print("✅ Enhanced subscription \(id) confirmed")
                    return
                }
                
                // Handle transaction notifications
                if let method = json["method"] as? String,
                   method == "transactionNotification",
                   let params = json["params"] as? [String: Any] {
                    
                    processTransactionNotification(params)
                }
            }
        } catch {
            print("❌ Error parsing enhanced detection message: \(error)")
        }
    }
    
    private func processTransactionNotification(_ params: [String: Any]) {
        guard let result = params["result"] as? [String: Any],
              let transaction = result["transaction"] as? [String: Any] else {
            return
        }
        
        // Analyze transaction for pool creation or token minting
        analyzeTransactionForNewAssets(transaction)
    }
    
    private func analyzeTransactionForNewAssets(_ transaction: [String: Any]) {
        // Look for Raydium pool initialization logs
        if let logs = transaction["meta"] as? [String: Any],
           let logMessages = logs["logMessages"] as? [String] {
            
            // Check for Raydium pool creation
            for log in logMessages {
                if log.contains("initialize2: InitializeInstruction2") {
                    print("🎯 New Raydium pool detected via enhanced detection!")
                    
                    // Extract pool details and create TradingPair
                    if let newPool = extractRaydiumPoolInfo(from: transaction) {
                        newPoolsDetected.append(newPool)
                        
                        // Keep only last 50 pools
                        if newPoolsDetected.count > 50 {
                            newPoolsDetected = Array(newPoolsDetected.suffix(50))
                        }
                    }
                    break
                }
                
                // Check for token mint operations
                if log.contains("mintTo") || log.contains("initializeMint") {
                    print("🪙 New token mint detected via enhanced detection!")
                    
                    // Extract token details and create TokenCreation
                    if let newToken = extractTokenMintInfo(from: transaction) {
                        newTokensDetected.append(newToken)
                        
                        // Keep only last 50 tokens
                        if newTokensDetected.count > 50 {
                            newTokensDetected = Array(newTokensDetected.suffix(50))
                        }
                    }
                    break
                }
            }
        }
    }
    
    // MARK: - Enhanced RPC Methods for Token Discovery
    
    private func startPeriodicTokenScanning() {
        // Use Helius Enhanced RPC methods every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.scanForNewTokensViaRPC()
            }
        }
    }
    
    private func scanForNewTokensViaRPC() async {
        // Use Helius DAS API to get recently created assets
        await getRecentlyCreatedAssets()
    }
    
    private func getRecentlyCreatedAssets() async {
        do {
            let requestBody: [String: Any] = [
                "jsonrpc": "2.0",
                "id": "recent-assets",
                "method": "searchAssets",
                "params": [
                    "limit": 20,
                    "page": 1,
                    "sortBy": [
                        "sortBy": "created",
                        "sortDirection": "desc"
                    ],
                    "displayOptions": [
                        "showFungible": true
                    ]
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: URL(string: heliusDAS)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let items = result["items"] as? [[String: Any]] {
                
                print("📊 Found \(items.count) recently created assets via Enhanced RPC")
                
                // Process recently created assets
                for item in items {
                    if let tokenCreation = parseAssetToTokenCreation(item) {
                        if !newTokensDetected.contains(where: { $0.mint == tokenCreation.mint }) {
                            newTokensDetected.append(tokenCreation)
                        }
                    }
                }
                
                // Keep only last 100 tokens
                if newTokensDetected.count > 100 {
                    newTokensDetected = Array(newTokensDetected.suffix(100))
                }
            }
            
        } catch {
            print("❌ Error scanning for new tokens via Enhanced RPC: \(error)")
        }
    }
    
    // MARK: - Data Extraction Helpers
    
    private func extractRaydiumPoolInfo(from transaction: [String: Any]) -> TradingPair? {
        // Advanced parsing of Raydium pool creation transaction
        // Extract token mints, initial liquidity, creator, etc.
        
        // This would require detailed analysis of the transaction structure
        // For now, return nil - full implementation would parse account keys and instructions
        
        return nil
    }
    
    private func extractTokenMintInfo(from transaction: [String: Any]) -> TokenCreation? {
        // Advanced parsing of token mint transaction
        // Extract mint address, metadata, creator, etc.
        
        // This would require detailed analysis of the transaction structure
        // For now, return nil - full implementation would parse instructions and accounts
        
        return nil
    }
    
    private func parseAssetToTokenCreation(_ asset: [String: Any]) -> TokenCreation? {
        guard let id = asset["id"] as? String,
              let content = asset["content"] as? [String: Any],
              let metadata = content["metadata"] as? [String: Any],
              let name = metadata["name"] as? String,
              let symbol = metadata["symbol"] as? String else {
            return nil
        }
        
        let description = metadata["description"] as? String
        let image = asset["content"] as? [String: Any]
        let imageUri = (image?["links"] as? [String: Any])?["image"] as? String
        
        return TokenCreation(
            mint: id,
            name: name,
            symbol: symbol,
            description: description,
            image: imageUri,
            createdTimestamp: Date().timeIntervalSince1970 * 1000, // Current time as fallback
            creator: nil, // Could be extracted from ownership info
            totalSupply: nil, // Could be extracted from supply info
            initialLiquidity: nil, // Not available from DAS API
            raydiumPool: nil,
            complete: true,
            metadataUri: nil, // No metadata URI available from DAS API
            webSocketSocialLinks: nil, // No WebSocket social links from Helius
            // Pump.fun specific fields - nil for Helius Enhanced Detection
            marketCapSol: nil,
            solAmount: nil,
            initialBuy: nil,
            vSolInBondingCurve: nil,
            vTokensInBondingCurve: nil
        )
    }
    
    // MARK: - Connection Monitoring
    
    private func startConnectionMonitoring() {
        // Send periodic pings every 30 seconds
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        guard connectionStatus == .connected else { return }
        
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
                print("💔 Enhanced detection ping failed: \(error)")
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
        
        print("❌ Helius Enhanced Detection error: \(error)")
        
        // Implement exponential backoff reconnection
        if reconnectAttempts < maxReconnectAttempts {
            let delay = pow(2.0, Double(reconnectAttempts))
            reconnectAttempts += 1
            
            print("🔄 Reconnecting to Enhanced Detection in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                self.startEnhancedDetection()
            }
        } else {
            print("💀 Max Enhanced Detection reconnection attempts reached")
            connectionStatus = .error("Connection failed after \(maxReconnectAttempts) attempts")
        }
    }
    
    func reconnect() {
        stopEnhancedDetection()
        reconnectAttempts = 0
        startEnhancedDetection()
    }
    
    func clearDetectedAssets() {
        newTokensDetected.removeAll()
        newPoolsDetected.removeAll()
    }
}

// MARK: - Integration Helper

extension HeliusEnhancedDetectionManager {
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
        case .connected: return "Enhanced Detection Connected"
        case .connecting: return "Connecting to Enhanced Detection..."
        case .disconnected: return "Enhanced Detection Disconnected"
        case .error(let message): return "Enhanced Detection Error: \(message)"
        }
    }
}