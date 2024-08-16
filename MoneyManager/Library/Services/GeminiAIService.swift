//
//  GeminiAIService.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Core Google Gemini AI service handling REST API calls for MintAI assistant, financial analytics, key validation, and resilient model fallback.
//

import Foundation

class GeminiAIService {
    
    static let shared = GeminiAIService()
    
    private init() {}
    
    /// Priority list of candidate Gemini models to try across Google AI Studio API versions
    private let candidateModels = [
        "gemini-3.5-flash-lite",
        "gemini-2.0-flash",
        "gemini-2.0-flash-exp",
        "gemini-2.5-flash",
        "gemini-1.5-flash-latest",
        "gemini-1.5-flash",
        "gemini-1.5-pro"
    ]
    
    private let UD_WORKING_GEMINI_MODEL = "working_gemini_model"
    
    /// Reads active working model name
    var activeModel: String {
        get {
            return UserDefaults.standard.string(forKey: UD_WORKING_GEMINI_MODEL) ?? "gemini-3.5-flash-lite"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UD_WORKING_GEMINI_MODEL)
        }
    }
    
    /// Reads stored API key from Keychain
    var apiKey: String? {
        get {
            return KeychainHelper.shared.read(forKey: KEYCHAIN_GEMINI_KEY)
        }
        set {
            if let val = newValue {
                var clean = val.trimmingCharacters(in: .whitespacesAndNewlines)
                clean = clean.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                if !clean.isEmpty {
                    KeychainHelper.shared.save(clean, forKey: KEYCHAIN_GEMINI_KEY)
                } else {
                    KeychainHelper.shared.delete(forKey: KEYCHAIN_GEMINI_KEY)
                }
            } else {
                KeychainHelper.shared.delete(forKey: KEYCHAIN_GEMINI_KEY)
            }
        }
    }
    
    var isKeyConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Validates a given API key by testing candidate models sequentially until one succeeds.
    func validateApiKey(_ key: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        var cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanKey = cleanKey.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
        
        guard !cleanKey.isEmpty else {
            completion(.failure(NSError(domain: "GeminiAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key cannot be empty"])))
            return
        }
        
        testNextCandidateModel(candidateIndex: 0, cleanKey: cleanKey, lastError: nil, completion: completion)
    }
    
    private func testNextCandidateModel(candidateIndex: Int, cleanKey: String, lastError: Error?, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard candidateIndex < candidateModels.count else {
            let finalError = lastError ?? NSError(domain: "GeminiAIService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No compatible Gemini model found for this API key. Please check Google AI Studio API permissions."])
            DispatchQueue.main.async { completion(.failure(finalError)) }
            return
        }
        
        let modelName = candidateModels[candidateIndex]
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(cleanKey)"
        guard let url = URL(string: urlString) else {
            testNextCandidateModel(candidateIndex: candidateIndex + 1, cleanKey: cleanKey, lastError: lastError, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Hi"]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "GeminiAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to construct request payload"])))
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"]))) }
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Success! Save working model name & save sanitized API key
                self?.activeModel = modelName
                self?.apiKey = cleanKey
                DispatchQueue.main.async { completion(.success(true)) }
            } else {
                var errDetail = "API Key Validation Failed (HTTP Status \(httpResponse.statusCode))"
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDict = json["error"] as? [String: Any], let msg = errorDict["message"] as? String {
                    errDetail = msg
                }
                
                let isModelUnavailable = httpResponse.statusCode == 404 ||
                                         errDetail.contains("not found") ||
                                         errDetail.contains("not supported") ||
                                         errDetail.contains("no longer available") ||
                                         errDetail.contains("Please update your code")
                
                // If model is not supported or deprecated, try next candidate model
                if isModelUnavailable {
                    let candidateErr = NSError(domain: "GeminiAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errDetail])
                    self?.testNextCandidateModel(candidateIndex: candidateIndex + 1, cleanKey: cleanKey, lastError: candidateErr, completion: completion)
                } else {
                    // Critical auth error (e.g. HTTP 400 Invalid Key or HTTP 403 Forbidden) -> fail with exact message
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "GeminiAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errDetail])))
                    }
                }
            }
        }.resume()
    }
    
    /// Queries MintAI with user prompt and current financial context.
    func askMintAI(userQuery: String, financialContext: String, userName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            completion(.failure(NSError(domain: "GeminiAIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key is missing. Please configure key in Settings."])))
            return
        }
        
        executeGenerateContent(userQuery: userQuery, financialContext: financialContext, userName: userName, key: key, modelIndex: 0, completion: completion)
    }
    
    private func executeGenerateContent(userQuery: String, financialContext: String, userName: String, key: String, modelIndex: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let modelName = modelIndex == 0 ? activeModel : (modelIndex - 1 < candidateModels.count ? candidateModels[modelIndex - 1] : activeModel)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(key)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "GeminiAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API endpoint URL"])))
            return
        }
        
        let systemPrompt = """
        You are MintAI, an intelligent, empathetic, and expert personal financial coach inside the TrackMint iOS expense tracking app.
        The user's preferred name is '\(userName)'.
        
        Below is the real-time financial context of \(userName)'s TrackMint account:
        --- FINANCIAL CONTEXT ---
        \(financialContext)
        --- END CONTEXT ---
        
        Instructions:
        1. Answer \(userName)'s question accurately based strictly on their transaction history and financial summary.
        2. Keep your answers concise, encouraging, structured with bullet points if helpful, and formatted cleanly.
        3. Do not invent non-existent transactions. If the data is empty or insufficient, politely explain and guide them.
        4. Provide actionable financial tips or savings recommendations when asked.
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemPrompt)\n\nUser Question: \(userQuery)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "maxOutputTokens": 800
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "GeminiAIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to construct request payload"])))
            return
        }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"]))) }
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Save successful model
                self?.activeModel = modelName
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCand = candidates.first,
                   let content = firstCand["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    DispatchQueue.main.async { completion(.success(text)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "GeminiAIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not parse Gemini response content"]))) }
                }
            } else {
                var errDetail = "Gemini API Error (HTTP Status \(httpResponse.statusCode))"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorDict = json["error"] as? [String: Any], let msg = errorDict["message"] as? String {
                    errDetail = msg
                }
                
                let isModelUnavailable = httpResponse.statusCode == 404 ||
                                         errDetail.contains("not found") ||
                                         errDetail.contains("not supported") ||
                                         errDetail.contains("no longer available") ||
                                         errDetail.contains("Please update your code")
                
                if isModelUnavailable && modelIndex < self?.candidateModels.count ?? 0 {
                    self?.executeGenerateContent(userQuery: userQuery, financialContext: financialContext, userName: userName, key: key, modelIndex: modelIndex + 1, completion: completion)
                } else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "GeminiAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errDetail]))) }
                }
            }
        }.resume()
    }
}
