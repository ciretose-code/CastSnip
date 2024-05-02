//
//  EpisodeView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 5/1/24.
//

import SwiftUI

struct EpisodeView: View {
    var episode: String
    @State var episodeField: String = ""
    
    var body: some View {
        Text("Episode")
            .font(.system(.subheadline).lowercaseSmallCaps())
        TextField(episode, text: $episodeField)
            .textFieldStyle(.roundedBorder)
    }
}
