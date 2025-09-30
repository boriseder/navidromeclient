import UIKit

class AlbumCoverArt {
    internal let baseImage: UIImage
    private let baseSize: Int
    private var scaledVariants: [Int: UIImage] = [:]
    private let lock = NSLock()
    private let maxVariants = 3
    
    // Store only ONE base image per album
    init(image: UIImage, size: Int) {
        self.baseImage = image
        self.baseSize = size
    }
    
    func getImage(for requestedSize: Int) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        
        // Exact match for base size
        if requestedSize == baseSize {
            return baseImage
        }
        
        // Check cached variants
        if let cached = scaledVariants[requestedSize] {
            return cached
        }
        
        // Background scaling for non-cached sizes
        let scaled = scaleImageEfficiently(baseImage, to: requestedSize)
        
        // Limit cached variants to prevent memory growth
        if scaledVariants.count >= maxVariants {
            let oldestKey = scaledVariants.keys.first!
            scaledVariants.removeValue(forKey: oldestKey)
        }
        
        scaledVariants[requestedSize] = scaled
        return scaled
    }
    
    private func scaleImageEfficiently(_ image: UIImage, to size: Int) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // Accurate memory footprint for NSCache cost calculation
    var memoryFootprint: Int {
        let baseMemory = Int(baseImage.size.width * baseImage.size.height * 4)
        let variantMemory = scaledVariants.values.reduce(0) { total, image in
            total + Int(image.size.width * image.size.height * 4)
        }
        return baseMemory + variantMemory
    }
    
    func hasAnyImage() -> Bool {
        return true // Always has base image
    }
    
    func getSizes() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return ([baseSize] + Array(scaledVariants.keys)).sorted()
    }
}
