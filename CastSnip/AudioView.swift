//
//  AudioView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/20/24.
//

import SwiftUI
import DSWaveformImageViews

struct AudioView: View {

    @State var audioURL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!

    var body: some View {
        VStack {
            WaveformView(audioURL: audioURL) { waveformShape in
                waveformShape.fill(Color.purple)
            } placeholder: {
                ProgressView()
            }
            
        }
    }
    
    
}

struct TimeUnit: Shape {
    let num: Int
    let ticks: [Tick]
    
    func path(in rect: CGRect) -> Path {
        let distance = rect.width / CGFloat(ticks.count)
        var path = Path()
        var x = rect.minX
        for tick in ticks {
            switch tick {
            case .major:
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            case .mid:
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - 16))
            case .minor:
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - 8))
            }
            x += distance
            print("tick")
        }
        return path
    }
}

enum Tick {
    case major, mid, minor
}
