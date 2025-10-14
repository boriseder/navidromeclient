//
//  ImageContext.swift
//  NavidromeClient
//
//  Defines display contexts for images with optimal sizes
//  Each context represents a specific UI use case
//

import Foundation

enum ImageContext {
    // Album Display Contexts
    case list
    case card
    case grid
    case detail
    case hero
    case fullscreen
    case miniPlayer
    
    // Artist Display Contexts
    case artistList
    case artistCard
    case artistHero
    
    var size: Int {
        switch self {
        case .list:
            return 80
        case .card, .miniPlayer:
            return 150
        case .grid:
            return 200
        case .artistList:
            return 100
        case .artistCard:
            return 150
        case .artistHero:
            return 240
        case .detail:
            return 300
        case .hero:
            return 400
        case .fullscreen:
            return 800
        }
    }
    
    var displaySize: CGFloat {
        return CGFloat(size)
    }
    
    var isAlbumContext: Bool {
        switch self {
        case .list, .card, .grid, .detail, .hero, .fullscreen, .miniPlayer:
            return true
        case .artistList, .artistCard, .artistHero:
            return false
        }
    }
    
    var isArtistContext: Bool {
        return !isAlbumContext
    }
}
