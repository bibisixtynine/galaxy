//
//  MenuView.swift
//  galaxy
//

import SwiftUI

// MARK: - Menu View
struct MenuView: View {
    let gameTime: Double
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Title
            VStack(spacing: 5) {
                Text("GALAXY")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [RetroColors.neonPink, RetroColors.neonPurple, RetroColors.neonBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: RetroColors.neonPink, radius: 20)
                    .shadow(color: RetroColors.neonPurple, radius: 40)
                
                Text("INVADERS")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [RetroColors.neonGreen, RetroColors.neonBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: RetroColors.neonGreen, radius: 15)
            }
            .scaleEffect(1 + 0.02 * sin(gameTime * 2))
            
            // Demo invaders
            HStack(spacing: 30) {
                ForEach(0..<3, id: \.self) { type in
                    PixelShape(pixels: InvaderSprites.sprite(type: type, frame: Int(gameTime * 2) % 2))
                        .fill(InvaderSprites.color(type: type))
                        .frame(width: 40, height: 40)
                        .shadow(color: InvaderSprites.color(type: type), radius: 10)
                        .offset(y: 5 * sin(gameTime * 3 + Double(type)))
                }
            }
            .padding(.vertical, 20)
            
            // Start button
            Button(action: onStart) {
                Text("TAP TO START")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(RetroColors.neonGreen)
                            .shadow(color: RetroColors.neonGreen, radius: 15)
                    )
            }
            .opacity(0.7 + 0.3 * sin(gameTime * 4))
            
            // Instructions
            VStack(spacing: 10) {
                Text("DRAG TO MOVE • TAP TO FIRE")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(RetroColors.retroWhite.opacity(0.6))
            }
            .padding(.top, 30)
        }
    }
}
