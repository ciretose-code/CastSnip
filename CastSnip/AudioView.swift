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
    
    @EnvironmentObject var audioModel: PodcastAudioViewModel
    @State var playPause = PLAY_ICON
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing:2) {
                WaveformView(audioURL: audioModel.podcast.url) { waveformShape in
                    waveformShape.fill(Color.purple)
                } placeholder: {
                    ProgressView()
                }.frame(width: geometry.size.width, height: geometry.size.height/2)
                
                
                
//                Timeline(chapters: audioModel.chapters, timelineWidth: geometry.size.width, audioDuration: audioModel.duration)
//                    .frame(width: geometry.size.width, height: 8)
                
                
                
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
        @State var chapters:[Chapter]
        @State var timelineWidth:CGFloat
        @State var audioDuration:CMTime
        
        var body: some View {
            HStack(spacing: 0) {
                ForEach(chapters) { chapter in
//                    Image(systemName: "\(num).circle")
//                    let pixelOffset = (audioDuration.value == 0) ? 0.0 : CGFloat((Double(chapter.offset.value/audioDuration.value)))*timelineWidth
//                    TimelineMarker(offset: pixelOffset)
//                        .stroke(.blue, lineWidth: 1)
//                        .frame(width: 20)
                }
            }
        }
    }
    
    struct TimelineMarker: Shape {
        let offset: CGFloat
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: offset, y: rect.minY))
            path.addLine(to: CGPoint(x: offset, y: rect.maxY))
            return path
        }
    }
}


struct AudioView_Previews: PreviewProvider {
    static var previews: some View {
        AudioView().previewLayout(.fixed(width: 500, height: 100))
            .environmentObject(PodcastAudioViewModel())
    }
}
