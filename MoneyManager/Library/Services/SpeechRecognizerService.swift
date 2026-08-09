//
//  SpeechRecognizerService.swift
//  MoneyManager
//
//  Created for TrackMint.
//  On-device speech recognition service using Apple's SFSpeechRecognizer & AVAudioEngine.
//

import Foundation
import SwiftUI
import Speech
import AVFoundation

class SpeechRecognizerService: NSObject, ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var permissionDenied: Bool = false
    @Published var errorMessage: String? = nil
    
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
    }
    
    /// Requests microphone and speech recognition permissions, then starts or stops recording.
    func toggleRecording(onTranscriptUpdate: @escaping (String) -> Void, onCompletion: @escaping (String) -> Void) {
        if isRecording {
            stopRecording(onCompletion: onCompletion)
        } else {
            requestPermissions { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startRecording(onTranscriptUpdate: onTranscriptUpdate)
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        }
    }
    
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                completion(false)
                return
            }
            
            AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                completion(micGranted)
            }
        }
    }
    
    private func startRecording(onTranscriptUpdate: @escaping (String) -> Void) {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.errorMessage = "Failed to configure audio session."
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            self.errorMessage = "Unable to create speech request."
            return
        }
        
        if let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecording = true
                self.transcript = ""
                self.errorMessage = nil
            }
        } catch {
            self.errorMessage = "Audio engine failed to start."
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    onTranscriptUpdate(text)
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
    }
    
    func stopRecording(onCompletion: @escaping (String) -> Void) {
        let finalTranscript = transcript
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
        }
        
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}
        
        DispatchQueue.main.async {
            self.isRecording = false
            onCompletion(finalTranscript)
        }
    }
}
