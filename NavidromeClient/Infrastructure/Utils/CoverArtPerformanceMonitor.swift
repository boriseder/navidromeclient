import Foundation
import SwiftUI

@MainActor
class CoverArtPerformanceMonitor: ObservableObject {
    static let shared = CoverArtPerformanceMonitor()
    
    @Published var stats = Stats()
    
    struct Stats {
        var totalRequests = 0
        var cacheHits = 0
        var networkRequests = 0
        var duplicateRequests = 0
        
        var cacheHitRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(cacheHits) / Double(totalRequests) * 100
        }
        
        var duplicateRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(duplicateRequests) / Double(totalRequests) * 100
        }
    }
    
    private init() {}
    
    func recordRequest() {
        stats.totalRequests += 1
    }
    
    func recordCacheHit() {
        stats.cacheHits += 1
    }
    
    func recordNetworkRequest() {
        stats.networkRequests += 1
    }
    
    func recordDuplicate() {
        stats.duplicateRequests += 1
    }
    
    func reset() {
        stats = Stats()
    }
}
