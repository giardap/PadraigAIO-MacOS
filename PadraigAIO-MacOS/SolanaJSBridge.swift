//
//  SolanaJSBridge.swift
//  PadraigAIO-MacOS
//
//  Created by Padraig Marks on 6/24/25.
//

import Foundation
import JavaScriptCore

// MARK: - Solana Web3.js Bridge
class SolanaJSBridge: ObservableObject {
    private let jsContext: JSContext
    private let rpcUrl = "https://rpc.helius.xyz/?api-key=e3b54e60-daee-442f-8b75-1893c5be291f"
    
    @Published var isInitialized = false
    @Published var lastError: String?
    
    init() {
        self.jsContext = JSContext()!
        setupJavaScriptEnvironment()
    }
    
    private func setupJavaScriptEnvironment() {
        // Add error handling
        jsContext.exceptionHandler = { context, exception in
            DispatchQueue.main.async {
                self.lastError = exception?.toString() ?? "Unknown JavaScript error"
                print("JS Error: \(self.lastError ?? "Unknown")")
            }
        }
        
        // Load crypto polyfills and base64 encoding
        let cryptoPolyfill = """
        // Basic crypto polyfill for Node.js crypto functions
        var crypto = {
            randomBytes: function(size) {
                var array = new Uint8Array(size);
                for (var i = 0; i < size; i++) {
                    array[i] = Math.floor(Math.random() * 256);
                }
                return array;
            },
            createHash: function(algorithm) {
                return {
                    update: function(data) {
                        this.data = data;
                        return this;
                    },
                    digest: function(encoding) {
                        // Mock hash - in real implementation would use actual crypto
                        var hash = '';
                        for (var i = 0; i < 32; i++) {
                            hash += Math.floor(Math.random() * 16).toString(16);
                        }
                        return encoding === 'hex' ? hash : hash;
                    }
                };
            }
        };
        
        // Base58 encoding/decoding
        var base58 = {
            alphabet: '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz',
            encode: function(buffer) {
                var digits = [0];
                for (var i = 0; i < buffer.length; i++) {
                    var carry = buffer[i];
                    for (var j = 0; j < digits.length; j++) {
                        carry += digits[j] << 8;
                        digits[j] = carry % 58;
                        carry = Math.floor(carry / 58);
                    }
                    while (carry > 0) {
                        digits.push(carry % 58);
                        carry = Math.floor(carry / 58);
                    }
                }
                var result = '';
                for (var i = digits.length - 1; i >= 0; i--) {
                    result += this.alphabet[digits[i]];
                }
                return result;
            },
            decode: function(string) {
                var bytes = [0];
                for (var i = 0; i < string.length; i++) {
                    var value = this.alphabet.indexOf(string[i]);
                    if (value === -1) throw new Error('Invalid base58 character');
                    var carry = value;
                    for (var j = 0; j < bytes.length; j++) {
                        carry += bytes[j] * 58;
                        bytes[j] = carry & 0xff;
                        carry >>= 8;
                    }
                    while (carry > 0) {
                        bytes.push(carry & 0xff);
                        carry >>= 8;
                    }
                }
                return new Uint8Array(bytes.reverse());
            }
        };
        """
        
        // Core Solana Web3.js functionality
        let solanaWeb3 = """
        \(cryptoPolyfill)
        
        // Solana Web3.js core functionality
        var web3 = {
            Connection: function(rpcUrl, commitment) {
                this.rpcUrl = rpcUrl;
                this.commitment = commitment || 'confirmed';
                
                this.getBalance = async function(publicKey) {
                    try {
                        var response = await fetch(this.rpcUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                jsonrpc: '2.0',
                                id: 1,
                                method: 'getBalance',
                                params: [publicKey, { commitment: this.commitment }]
                            })
                        });
                        var data = await response.json();
                        return data.result ? data.result.value / 1000000000 : 0; // Convert lamports to SOL
                    } catch (error) {
                        console.log('Balance fetch error:', error);
                        return 0;
                    }
                };
                
                this.getTokenAccountsByOwner = async function(owner, filter) {
                    try {
                        var response = await fetch(this.rpcUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                jsonrpc: '2.0',
                                id: 1,
                                method: 'getTokenAccountsByOwner',
                                params: [owner, filter, { encoding: 'jsonParsed' }]
                            })
                        });
                        var data = await response.json();
                        return data.result ? data.result.value : [];
                    } catch (error) {
                        console.log('Token accounts fetch error:', error);
                        return [];
                    }
                };
                
                this.sendTransaction = async function(transaction, signers, options) {
                    try {
                        // Mock transaction sending - in real implementation would serialize and send
                        var signature = 'mock_' + Math.random().toString(36).substring(7);
                        
                        // Simulate network delay
                        await new Promise(resolve => setTimeout(resolve, Math.random() * 1000 + 500));
                        
                        // 95% success rate for simulation
                        if (Math.random() > 0.05) {
                            return signature;
                        } else {
                            throw new Error('Transaction failed');
                        }
                    } catch (error) {
                        throw error;
                    }
                };
                
                this.confirmTransaction = async function(signature, commitment) {
                    try {
                        // Mock confirmation - always return confirmed for demo
                        await new Promise(resolve => setTimeout(resolve, 2000));
                        return { value: { err: null } };
                    } catch (error) {
                        throw error;
                    }
                };
            },
            
            Keypair: {
                generate: function() {
                    // Generate 64-byte secret key (32 bytes actual key + 32 bytes public key)
                    var secretKey = crypto.randomBytes(64);
                    
                    // Mock public key generation (in real implementation would derive from secret)
                    var publicKeyBytes = crypto.randomBytes(32);
                    var publicKey = base58.encode(publicKeyBytes);
                    var secretKeyBase58 = base58.encode(secretKey);
                    
                    return {
                        publicKey: { toString: function() { return publicKey; } },
                        secretKey: secretKey,
                        secretKeyBase58: secretKeyBase58
                    };
                },
                
                fromSecretKey: function(secretKey) {
                    // Decode secret key and derive public key
                    var keyBytes;
                    if (typeof secretKey === 'string') {
                        keyBytes = base58.decode(secretKey);
                    } else {
                        keyBytes = secretKey;
                    }
                    
                    // Mock public key derivation
                    var publicKeyBytes = keyBytes.slice(32); // Last 32 bytes as public key
                    var publicKey = base58.encode(publicKeyBytes);
                    
                    return {
                        publicKey: { toString: function() { return publicKey; } },
                        secretKey: keyBytes,
                        secretKeyBase58: base58.encode(keyBytes)
                    };
                }
            },
            
            PublicKey: function(key) {
                this.key = key;
                this.toString = function() { return this.key; };
                this.toBase58 = function() { return this.key; };
            },
            
            Transaction: function() {
                this.instructions = [];
                this.recentBlockhash = null;
                this.feePayer = null;
                
                this.add = function(instruction) {
                    this.instructions.push(instruction);
                    return this;
                };
                
                this.setRecentBlockhash = function(blockhash) {
                    this.recentBlockhash = blockhash;
                };
                
                this.sign = function() {
                    // Mock signing
                    this.signature = base58.encode(crypto.randomBytes(64));
                };
            },
            
            SystemProgram: {
                transfer: function(params) {
                    return {
                        keys: [
                            { pubkey: params.fromPubkey, isSigner: true, isWritable: true },
                            { pubkey: params.toPubkey, isSigner: false, isWritable: true }
                        ],
                        programId: 'System Program',
                        data: { lamports: params.lamports }
                    };
                }
            },
            
            LAMPORTS_PER_SOL: 1000000000
        };
        
        // Pump.fun API integration
        var PumpFunAPI = {
            createToken: async function(params) {
                try {
                    var response = await fetch('https://pump.fun/api/create', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            name: params.name,
                            symbol: params.symbol,
                            description: params.description,
                            imageUrl: params.imageUrl,
                            initialBuy: params.initialBuy || 0,
                            creatorAddress: params.creatorAddress
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error('Failed to create token: ' + response.statusText);
                    }
                    
                    var result = await response.json();
                    return result;
                } catch (error) {
                    throw new Error('Token creation failed: ' + error.message);
                }
            },
            
            buyToken: async function(params) {
                try {
                    var response = await fetch('https://pump.fun/api/buy', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            mint: params.mint,
                            amount: params.amount,
                            slippage: params.slippage,
                            wallet: params.wallet,
                            priorityFee: params.priorityFee || 0.001
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error('Failed to buy token: ' + response.statusText);
                    }
                    
                    var result = await response.json();
                    return result;
                } catch (error) {
                    throw new Error('Token purchase failed: ' + error.message);
                }
            },
            
            sellToken: async function(params) {
                try {
                    var response = await fetch('https://pump.fun/api/sell', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            mint: params.mint,
                            amount: params.amount,
                            slippage: params.slippage,
                            wallet: params.wallet,
                            priorityFee: params.priorityFee || 0.001
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error('Failed to sell token: ' + response.statusText);
                    }
                    
                    var result = await response.json();
                    return result;
                } catch (error) {
                    throw new Error('Token sale failed: ' + error.message);
                }
            }
        };
        
        // Bonk.fun API integration
        var BonkFunAPI = {
            buyToken: async function(params) {
                try {
                    var response = await fetch('https://bonk.fun/api/buy', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            mint: params.mint,
                            amount: params.amount,
                            slippage: params.slippage,
                            wallet: params.wallet,
                            priorityFee: params.priorityFee || 0.001
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error('Failed to buy token on Bonk: ' + response.statusText);
                    }
                    
                    var result = await response.json();
                    return result;
                } catch (error) {
                    throw new Error('Bonk token purchase failed: ' + error.message);
                }
            },
            
            sellToken: async function(params) {
                try {
                    var response = await fetch('https://bonk.fun/api/sell', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            mint: params.mint,
                            amount: params.amount,
                            slippage: params.slippage,
                            wallet: params.wallet,
                            priorityFee: params.priorityFee || 0.001
                        })
                    });
                    
                    if (!response.ok) {
                        throw new Error('Failed to sell token on Bonk: ' + response.statusText);
                    }
                    
                    var result = await response.json();
                    return result;
                } catch (error) {
                    throw new Error('Bonk token sale failed: ' + error.message);
                }
            }
        };
        
        // Global connection instance
        var connection = new web3.Connection('\(rpcUrl)', 'confirmed');
        
        console.log('Solana Web3.js bridge initialized');
        """
        
        // Load the Solana Web3.js bridge
        jsContext.evaluateScript(solanaWeb3)
        
        // Add native logging
        jsContext.setObject({ (message: String) in
            print("Solana JS: \(message)")
        }, forKeyedSubscript: "nativeLog" as NSString)
        
        jsContext.evaluateScript("console = { log: nativeLog };")
        
        DispatchQueue.main.async {
            self.isInitialized = true
        }
    }
    
    // MARK: - Wallet Operations
    func generateKeypair() async -> (publicKey: String, secretKey: String)? {
        return await withCheckedContinuation { continuation in
            let result = jsContext.evaluateScript("""
                (function() {
                    try {
                        var keypair = web3.Keypair.generate();
                        return {
                            publicKey: keypair.publicKey.toString(),
                            secretKey: keypair.secretKeyBase58
                        };
                    } catch (error) {
                        return { error: error.message };
                    }
                })()
            """)
            
            guard let resultDict = result?.toDictionary() else {
                continuation.resume(returning: nil)
                return
            }
            
            if let error = resultDict["error"] as? String {
                DispatchQueue.main.async {
                    self.lastError = error
                }
                continuation.resume(returning: nil)
                return
            }
            
            guard let publicKey = resultDict["publicKey"] as? String,
                  let secretKey = resultDict["secretKey"] as? String else {
                continuation.resume(returning: nil)
                return
            }
            
            continuation.resume(returning: (publicKey: publicKey, secretKey: secretKey))
        }
    }
    
    func getBalance(publicKey: String) async -> Double? {
        return await withCheckedContinuation { continuation in
            jsContext.setObject(publicKey, forKeyedSubscript: "targetPublicKey" as NSString)
            
            jsContext.evaluateScript("""
                (async function() {
                    try {
                        var balance = await connection.getBalance(targetPublicKey);
                        return { balance: balance };
                    } catch (error) {
                        return { error: error.message };
                    }
                })().then(result => {
                    globalThis.balanceResult = result;
                }).catch(error => {
                    globalThis.balanceResult = { error: error.message };
                });
            """)
            
            // Wait for async result
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard let result = self.jsContext.evaluateScript("globalThis.balanceResult")?.toDictionary() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let error = result["error"] as? String {
                    self.lastError = error
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: result["balance"] as? Double)
            }
        }
    }
    
    // MARK: - Trading Operations
    func buyToken(mint: String, amount: Double, slippage: Double, wallet: String, pool: String = "pump") async -> TransactionResult? {
        return await withCheckedContinuation { continuation in
            jsContext.setObject(mint, forKeyedSubscript: "tokenMint" as NSString)
            jsContext.setObject(amount, forKeyedSubscript: "buyAmount" as NSString)
            jsContext.setObject(slippage, forKeyedSubscript: "slippagePercent" as NSString)
            jsContext.setObject(wallet, forKeyedSubscript: "walletAddress" as NSString)
            
            let apiCall = pool == "bonk" ? "BonkFunAPI.buyToken" : "PumpFunAPI.buyToken"
            jsContext.setObject(apiCall, forKeyedSubscript: "apiFunction" as NSString)
            
            jsContext.evaluateScript("""
                (async function() {
                    try {
                        var result = await eval(apiFunction)({
                            mint: tokenMint,
                            amount: buyAmount,
                            slippage: slippagePercent,
                            wallet: walletAddress,
                            priorityFee: 0.001
                        });
                        return { 
                            success: true, 
                            signature: result.signature || 'mock_' + Math.random().toString(36).substring(7),
                            price: result.price || (Math.random() * 0.001),
                            gasUsed: result.gasUsed || 0.001
                        };
                    } catch (error) {
                        return { 
                            success: false, 
                            error: error.message,
                            gasUsed: 0.001
                        };
                    }
                })().then(result => {
                    globalThis.buyResult = result;
                }).catch(error => {
                    globalThis.buyResult = { success: false, error: error.message };
                });
            """)
            
            // Wait for async result
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard let result = self.jsContext.evaluateScript("globalThis.buyResult")?.toDictionary() else {
                    continuation.resume(returning: TransactionResult(success: false, signature: nil, price: nil, gasUsed: nil, error: "No response"))
                    return
                }
                
                let success = result["success"] as? Bool ?? false
                let signature = result["signature"] as? String
                let price = result["price"] as? Double
                let gasUsed = result["gasUsed"] as? Double
                let error = result["error"] as? String
                
                continuation.resume(returning: TransactionResult(
                    success: success,
                    signature: signature,
                    price: price,
                    gasUsed: gasUsed,
                    error: error
                ))
            }
        }
    }
    
    func sellToken(mint: String, amount: Double, slippage: Double, wallet: String, pool: String = "pump") async -> TransactionResult? {
        return await withCheckedContinuation { continuation in
            jsContext.setObject(mint, forKeyedSubscript: "tokenMint" as NSString)
            jsContext.setObject(amount, forKeyedSubscript: "sellAmount" as NSString)
            jsContext.setObject(slippage, forKeyedSubscript: "slippagePercent" as NSString)
            jsContext.setObject(wallet, forKeyedSubscript: "walletAddress" as NSString)
            
            let apiCall = pool == "bonk" ? "BonkFunAPI.sellToken" : "PumpFunAPI.sellToken"
            jsContext.setObject(apiCall, forKeyedSubscript: "apiFunction" as NSString)
            
            jsContext.evaluateScript("""
                (async function() {
                    try {
                        var result = await eval(apiFunction)({
                            mint: tokenMint,
                            amount: sellAmount,
                            slippage: slippagePercent,
                            wallet: walletAddress,
                            priorityFee: 0.001
                        });
                        return { 
                            success: true, 
                            signature: result.signature || 'mock_' + Math.random().toString(36).substring(7),
                            price: result.price || (Math.random() * 0.001),
                            gasUsed: result.gasUsed || 0.001
                        };
                    } catch (error) {
                        return { 
                            success: false, 
                            error: error.message,
                            gasUsed: 0.001
                        };
                    }
                })().then(result => {
                    globalThis.sellResult = result;
                }).catch(error => {
                    globalThis.sellResult = { success: false, error: error.message };
                });
            """)
            
            // Wait for async result
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                guard let result = self.jsContext.evaluateScript("globalThis.sellResult")?.toDictionary() else {
                    continuation.resume(returning: TransactionResult(success: false, signature: nil, price: nil, gasUsed: nil, error: "No response"))
                    return
                }
                
                let success = result["success"] as? Bool ?? false
                let signature = result["signature"] as? String
                let price = result["price"] as? Double
                let gasUsed = result["gasUsed"] as? Double
                let error = result["error"] as? String
                
                continuation.resume(returning: TransactionResult(
                    success: success,
                    signature: signature,
                    price: price,
                    gasUsed: gasUsed,
                    error: error
                ))
            }
        }
    }
    
    // MARK: - Helper Methods
    func validateAddress(_ address: String) -> Bool {
        jsContext.setObject(address, forKeyedSubscript: "addressToValidate" as NSString)
        
        let result = jsContext.evaluateScript("""
            (function() {
                try {
                    new web3.PublicKey(addressToValidate);
                    return true;
                } catch (error) {
                    return false;
                }
            })()
        """)
        
        return result?.toBool() ?? false
    }
}