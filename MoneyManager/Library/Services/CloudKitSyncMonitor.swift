//
//  CloudKitSyncMonitor.swift
//  MoneyManager
//
//  Created for TrackMint.
//  Monitors NSPersistentCloudKitContainer sync events and exposes live syncing status.
//

import Foundation
import SwiftUI
import CoreData

class CloudKitSyncMonitor: ObservableObject {
    
    static let shared = CloudKitSyncMonitor()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String? = nil
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
    }
    
    @objc private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        
        DispatchQueue.main.async {
            if event.endDate == nil {
                self.isSyncing = true
            } else {
                self.isSyncing = false
                if let error = event.error {
                    self.lastSyncError = error.localizedDescription
                }
            }
        }
    }
}
