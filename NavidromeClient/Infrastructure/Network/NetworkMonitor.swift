//
//  NetworkMonitor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 11.09.25.
//


import Foundation
import Network
import SwiftUI

// MARK: - Network Monitor
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NetworkConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum NetworkConnectionType {
        case wifi, cellular, ethernet, unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                if self?.isConnected == true {
                    print("📶 Network connected: \(self?.connectionType ?? .unknown)")
                } else {
                    print("📵 Network disconnected")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}