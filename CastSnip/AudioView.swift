//
//  AudioView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/20/24.
//

import SwiftUI
import DSWaveformImageViews
import AVFoundation


let PLAY_ICON = "play.circle"
let PAUSE_ICON = "pause.circle"

struct AudioView: View {
    
    @EnvironmentObject var globalModel: GlobalModel
    @State var playPause = PLAY_ICON
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing:2) {
                WaveformView(audioURL: globalModel.audioURL) { waveformShape in
                    waveformShape.fill(Color.purple)
                } placeholder: {
                    ProgressView()
                }.frame(width: geometry.size.width, height: geometry.size.height/2)
                Timeline(timelineWidth: geometry.size.width)
                    .frame(width: geometry.size.width, height: 8)
                HStack {
                    Button(action: goToStart) {
                        Image(systemName: "backward.end.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(48)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: jumpBack15) {
                        Image(systemName: "gobackward.15")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(48)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: playPauseAudio) {
                        Image(systemName: playPause)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .cornerRadius(48)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: jumpForward15) {
                        Image(systemName: "goforward.15")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(48)
                    }.buttonStyle(BorderlessButtonStyle())
                    Button(action: jumpBack15) {
                        Image(systemName: "forward.end.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .cornerRadius(48)
                    }.buttonStyle(BorderlessButtonStyle())
                }.padding()
                
            }.padding()
        }
    }
    
    
    func goToStart() {
        
    }
    
    func playPauseAudio() {
        if playPause == PLAY_ICON {
            playPause = PAUSE_ICON
        } else {
            playPause = PLAY_ICON
        }
    }
    
    func goToEnd() {
        
    }
    
    func jumpBack15() {
        
    }
    
    func jumpForward15() {
        
    }


struct Timeline: View {

    @State var timelineWidth:CGFloat = 0
    
    let ticks: [Tick] = [.major, .minor, .mid, .minor, .mid, .minor, .mid, .minor, .mid, .minor]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { num in
                TimeUnit(num: num, ticks: ticks)
                    .stroke(.blue, lineWidth: 2)
                    .frame(width: timelineWidth)
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
                path.addLine(to: CGPoint(x: x, y: rect.maxY - 4))
            case .minor:
                path.move(to: CGPoint(x: x, y: rect.maxY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY - 2))
            }
            x += distance
        }
        return path
    }
}

enum Tick {
    case major, mid, minor
}
}


struct AudioView_Previews: PreviewProvider {
    static var previews: some View {
        AudioView().previewLayout(.fixed(width: 500, height: 100)).environmentObject(GlobalModel())
    }
}
