//
//  DataScannerView.swift
//  MoneyManager
//
//  Created for TrackMint.
//  VisionKit DataScannerViewController wrapper (iOS 16+) for live camera text recognition.
//

import SwiftUI
import VisionKit

@available(iOS 16.0, *)
struct DataScannerView: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    var onScannedText: ([String]) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isPresented {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerView
        
        init(_ parent: DataScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                parent.onScannedText([text.transcript])
                parent.isPresented = false
            default:
                break
            }
        }
    }
}
