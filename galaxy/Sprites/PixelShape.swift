//
//  PixelShape.swift
//  galaxy
//

import SwiftUI

// MARK: - Pixel Art Shapes
struct PixelShape: Shape {
    let pixels: [[Int]]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pixelSize = rect.width / CGFloat(pixels[0].count)
        
        for (row, rowData) in pixels.enumerated() {
            for (col, pixel) in rowData.enumerated() {
                if pixel == 1 {
                    let x = CGFloat(col) * pixelSize
                    let y = CGFloat(row) * pixelSize
                    path.addRect(CGRect(x: x, y: y, width: pixelSize, height: pixelSize))
                }
            }
        }
        return path
    }
}
