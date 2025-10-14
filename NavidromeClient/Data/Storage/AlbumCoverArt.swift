//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  Multi-size image container with efficient scaling
//  FIXED: Fallback scaling, accurate memory footprint calculation
//

import UIKit

@MainActor
class AlbumCoverArt {
    private let baseImage: UIImage
    private let baseSize: Int
    private var scaledVariants: [Int: UIImage] = [:]
    private let maxVariants = 3
    
    init(image: UIImage, size: Int) {
        self.baseImage = image
        self.baseSize = size
    }
    
    func getImage(for requestedSize: Int) -> UIImage? {
        // Exact match for base size
        if requestedSize == baseSize {
            return baseImage
        }
        
        // Return cached variant if available
        if let cached = scaledVariants[requestedSize] {
            return cached
        }
        
        // FIXED: Fallback to on-demand scaling for immediate display
        // This prevents nil returns when size is not cached
        if abs(requestedSize - baseSize) > 50 {
            // Significant size difference - scale synchronously for immediate display
            let scaled = scaleImageSync(baseImage, to: requestedSize)
            
            // Cache it asynchronously for future use
            Task {
                await preloadSize(requestedSize)
            }
            
            return scaled
        }
        
        // Use base image if sizes are similar (within 50px)
        return baseImage
    }
    
    func preloadSize(_ requestedSize: Int) async {
        guard requestedSize != baseSize else { return }
        guard scaledVariants[requestedSize] == nil else { return }
        
        let scaled = await scaleImageAsync(baseImage, to: requestedSize)
        
        await MainActor.run {
            // Limit cached variants to prevent memory growth
            if scaledVariants.count >= maxVariants {
                // Remove least recently used (smallest size as proxy)
                if let oldestKey = scaledVariants.keys.sorted().first {
                    scaledVariants.removeValue(forKey: oldestKey)
                }
            }
            
            scaledVariants[requestedSize] = scaled
        }
    }
    
    private func scaleImageSync(_ image: UIImage, to size: Int) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func scaleImageAsync(_ image: UIImage, to size: Int) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            let targetSize = CGSize(width: size, height: size)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }.value
    }
    
    var memoryFootprint: Int {
        // FIXED: Accurate calculation using scale factor
        let scale = baseImage.scale
        let basePixelWidth = baseImage.size.width * scale
        let basePixelHeight = baseImage.size.height * scale
        let baseMemory = Int(basePixelWidth * basePixelHeight * 4) // RGBA = 4 bytes
        
        let variantMemory = scaledVariants.values.reduce(0) { total, image in
            let variantScale = image.scale
            let pixelWidth = image.size.width * variantScale
            let pixelHeight = image.size.height * variantScale
            return total + Int(pixelWidth * pixelHeight * 4)
        }
        
        return baseMemory + variantMemory
    }
    
    func hasSize(_ size: Int) -> Bool {
        return size == baseSize || scaledVariants[size] != nil
    }
    
    func getSizes() -> [Int] {
        return ([baseSize] + Array(scaledVariants.keys)).sorted()
    }
}
