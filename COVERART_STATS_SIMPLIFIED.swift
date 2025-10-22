struct CoverArtCacheStats {
    let diskCount: Int
    let diskSize: Int64
    let activeRequests: Int
    let errorCount: Int
    
    var summary: String {
        return "Disk: \(diskCount), Active: \(activeRequests), Errors: \(errorCount)"
    }
}

struct CoverArtHealthStatus {
    let isHealthy: Bool
    let statusDescription: String
}
