//
//  NetworkState.swift
//  NavidromeClient
//
//  Created by Boris Eder on 30.09.25.
//

import Foundation

struct NetworkState: Equatable {
    let isConnected: Bool
    let isConfigured: Bool
    let hasServerErrors: Bool
    let manualOfflineMode: Bool
    
    var contentLoadingStrategy: ContentLoadingStrategy {
        // CRITICAL: Check configuration FIRST
        if !isConfigured {
            return .setupRequired
        }
        
        // Then check network/server conditions
        if !isConnected {
            return .offlineOnly(reason: .noNetwork)
        }
        if hasServerErrors {
            return .offlineOnly(reason: .serverUnreachable)
        }
        if manualOfflineMode {
            return .offlineOnly(reason: .userChoice)
        }
        
        return .online
    }
    
    var debugDescription: String {
        """
        NetworkState:
        - Connected: \(isConnected)
        - Configured: \(isConfigured)
        - Server Errors: \(hasServerErrors)
        - Manual Offline: \(manualOfflineMode)
        → Strategy: \(contentLoadingStrategy.displayName)
        """
    }
}
