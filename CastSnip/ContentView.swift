//
//  ContentView.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AudioFile.self) var podcastAudioFile
    
    @State var radius: CGFloat = 6
    @State var insets: CGFloat = 16
    @State private var isDraggingOverCoverArt = false
    
    var body: some View {
        if podcastAudioFile.isLoading {
            VStack {
                ProgressView("Loading podcast...")
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .padding()
                Text("Parsing ID3 tags and chapters...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        ZStack {
                            if podcastAudioFile.hasCoverArt(), let coverArt = podcastAudioFile.getCoverArt() {
                                coverArt
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(radius*2)
                                    .overlay(RoundedRectangle(cornerRadius: radius*2).stroke(.secondary, lineWidth: 1.5))
                            } else {
                                Image(systemName: "waveform")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                        .frame(width: 180, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius*2)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.accentColor)
                                .opacity(isDraggingOverCoverArt ? 0.5 : 0)
                        )
                        .onTapGesture {
                            selectCoverArtImage()
                        }
                        #if os(macOS)
                        .onDrop(of: [.image], isTargeted: $isDraggingOverCoverArt) { providers in
                            handleCoverArtDrop(providers: providers)
                        }
                        #endif
                        
                        VStack(alignment: .leading) {
                            TitleView(radius: radius, title: podcastAudioFile.getTitle())
                            EpisodeView(radius: radius, episode: podcastAudioFile.getEpisode())
                            SummaryView(radius: radius, summary: podcastAudioFile.getSummary())
                        }.frame(minHeight: 180, maxHeight: 180)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        HStack() {
                            Spacer()
                            Text("File Size: \(podcastAudioFile.podcast.getFileSizeFormatted())").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule()).frame(minWidth:180)
                            Text("Running Time: \(ID3Parser.toTrackTime(millis:UInt32( (podcastAudioFile.podcast.durationInSeconds ?? 0)*1000), showHours: true))").monospaced().padding(EdgeInsets(top:2, leading: 8, bottom: 2, trailing: 8)).background(.gray).foregroundColor(.white).clipShape(Capsule())
                            Spacer()
                        }
                        ChapterTableView(radius: radius).environment(podcastAudioFile)
                        
                        // Waveform visualization
                        WaveformView(audioFile: podcastAudioFile.podcast.file, sampleCount: 200)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(radius)
                            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    }
                }.padding(EdgeInsets(top: insets, leading: insets, bottom: insets, trailing: insets))
            }
            .alert("Error Loading Podcast", isPresented: .constant(podcastAudioFile.errorMessage != nil)) {
                Button("OK") {
                    podcastAudioFile.errorMessage = nil
                }
            } message: {
                Text(podcastAudioFile.errorMessage ?? "")
            }
        }
//#if os(macOS)
//        .toolbar {
//            Button(action: openPodcastFile){
//                Label("Open MP3", systemImage: "plus")
//            }.help("Open MP3")
//            Button(action: savePodcastFile){
//                Label("Save MP3", systemImage: "square.and.arrow.up")
//            }.help("Save MP3")
//        }
//#endif
    }
    
    private func openPodcastFile() {
        
    }
    
    private func savePodcastFile() {
        
    }
    
    // MARK: - Cover Art Management
    
    #if os(macOS)
    private func handleCoverArtDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier("public.image") {
            provider.loadItem(forTypeIdentifier: "public.image", options: nil) { item, error in
                if let error = error {
                    print("Error loading dropped image: \(error.localizedDescription)")
                    return
                }
                
                var nsImage: NSImage?
                
                if let url = item as? URL {
                    nsImage = NSImage(contentsOf: url)
                } else if let data = item as? Data {
                    nsImage = NSImage(data: data)
                } else if let image = item as? NSImage {
                    nsImage = image
                }
                
                if let image = nsImage {
                    DispatchQueue.main.async {
                        podcastAudioFile.podcast.logo = image
                        print("Cover art updated via drag and drop")
                    }
                }
            }
            return true
        }
        
        return false
    }
    
    private func selectCoverArtImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.message = "Select a cover art image"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    podcastAudioFile.podcast.logo = image
                    print("Cover art updated via file selection: \(url.lastPathComponent)")
                }
            }
        }
    }
    #endif
}


#Preview("Load Sample Intro") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
                .task {
                    await audioModel.loadPodcast(from: Bundle.main.url(forResource:"intro", withExtension: "mp3")!)
                }
        }
    }
    return ContentTestView()
}

#Preview("Load Null") {
    struct ContentTestView: View {
        let audioModel = AudioFile()
        var body: some View {
            ContentView().environment(audioModel)
        }
    }
    return ContentTestView()
}