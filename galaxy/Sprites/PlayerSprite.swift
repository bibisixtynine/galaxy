//
//  PlayerSprite.swift
//  galaxy
//

import Foundation

// MARK: - Player Ship Sprite
struct PlayerSprite {
    static let pixels = [
        [0,0,0,0,0,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,0,0,0,0,0,1,1,0]
    ]
    
    // Ship broken into fragments for death explosion
    static let fragments: [[[Int]]] = [
        // Top spike
        [[0,0,1,0,0],
         [0,1,1,1,0],
         [0,1,1,1,0]],
        // Left wing
        [[0,1,1,1,0],
         [1,1,1,1,0],
         [1,1,1,0,0],
         [0,1,1,0,0]],
        // Right wing
        [[0,1,1,1,0],
         [0,1,1,1,1],
         [0,0,1,1,1],
         [0,0,1,1,0]],
        // Center body
        [[1,1,1],
         [1,1,1],
         [1,1,1]],
        // Left engine
        [[1,1],
         [1,1],
         [1,1]],
        // Right engine
        [[1,1],
         [1,1],
         [1,1]]
    ]
}
