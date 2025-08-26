//
//  Item.swift
//  NavidromeClient
//
//  Created by Boris Eder on 27.08.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
