//
//  ContentView.swift
//  AudioToTextPlayer
//
//  Created by Ian on 14/10/2023.
//

import AVKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var audioService = AudioVisualService(itemURL: "https://archive.org/download/acres_of_diamonds_1008_librivox/acresofdiamonds_05_conwell.mp3")
    
    var body: some View {
        ScrollView {
            VStack {
                VideoPlayer(player: audioService.player)
                    .frame(height: 200)
                    .frame(minWidth: 200)
                    .onAppear {
                        audioService.isPlaying = true
                    }
                
                TextEditor(text: $audioService.transcribedText)
                    .font(.title3)
                    .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

