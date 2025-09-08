//
//  SubsonicService+CoverArt.swift
//  NavidromeClient
//
//  Created by Boris Eder on 04.09.25.
//
import UIKit

@MainActor
extension SubsonicService {
    func getCoverArt(for coverId: String, size: Int = 300) async -> UIImage? {
        if let cached = cachedImage(for: coverId) { return cached }
        guard let url = buildURL(endpoint: "getCoverArt", params: ["id": coverId, "size": "\(size)"]) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cacheImage(image, key: coverId)
                return image
            } else {
                return nil
            }
        } catch {
            print("Failed to load cover art: \(error)")
            return nil
        }
    }
}
