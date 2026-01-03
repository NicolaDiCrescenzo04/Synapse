//
//  Item.swift
//  Synapse
//
//  Created by Nicola Di Crescenzo on 03/01/26.
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
