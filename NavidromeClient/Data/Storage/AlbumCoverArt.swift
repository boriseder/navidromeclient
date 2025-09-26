//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  Created by Boris Eder on 26.09.25.
//


//
//  AlbumCoverArt.swift
//  NavidromeClient
//
//  Multi-size image wrapper for NSCache
//

import UIKit

class AlbumCoverArt {
    private var images: [Int: UIImage] = [:]
    private let lock = NSLock()
    
    /// Store an image for a specific size
    func setImage(_ image: UIImage, for size: Int) {
        lock.lock()
        defer { lock.unlock() }
        images[size] = image
    }
    
    /// Get image for requested size (exact match or scaled from closest)
    func getImage(for size: Int) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        
        // Return exact match if available
        if let exact = images[size] {
            return exact
        }
        
        // Find closest available size
        guard let closestSize = images.keys.min(by: { abs($0 - size) < abs($1 - size) }),
              let sourceImage = images[closestSize] else {
            return nil
        }
        
        // Scale from closest size and cache the result
        let scaledImage = sourceImage.scaled(to: CGSize(width: size, height: size))
        images[size] = scaledImage
        return scaledImage
    }
    
    /// Check if any image is stored
    func hasAnyImage() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !images.isEmpty
    }
    
    /// Get all available sizes
    func getSizes() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return Array(images.keys).sorted()
    }
    
    /// Get memory footprint estimate
    func getMemoryFootprint() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return images.values.reduce(0) { total, image in
            total + Int(image.size.width * image.size.height * 4)
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /// Scale image to target size maintaining aspect ratio
    func scaled(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}