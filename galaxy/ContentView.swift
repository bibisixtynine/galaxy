//
//  ContentView.swift
//  galaxy
//
//  Created by Jérôme Binachon on 01/04/2026.
//

import SwiftUI

// MARK: - Content View
struct ContentView: View {
    var body: some View {
        GameView()
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
