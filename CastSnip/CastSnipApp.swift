//
//  CastSnipApp.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/19/24.
//

import SwiftUI
import AVFoundation


@main
struct CastSnipApp: App {
    
    @State var podcastAudioModel = PodcastAudioViewModel()

    @State var fileURL: URL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
    
    var body: some Scene {
        WindowGroup {
            ContentView().environment(podcastAudioModel).task {
                print("scene load")
                await podcastAudioModel.loadPodcast(from: fileURL)
            }
        }
        .onChange(of: fileURL) {
            print("onChange")
            Task.detached(priority: .high) {
                await podcastAudioModel.loadPodcast(from: fileURL)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                
            }
            
            
            CommandGroup(after: .newItem) {
                Button("Open...") {
                    let url = openPodcastFile()
                    print("URL: \(String(describing: url))")
                    if url != nil {
                        fileURL = url!
                    }
                }
                .keyboardShortcut("O", modifiers: .command)
            }
            
            CommandGroup(before: .help){
                Button("mostlysecurity.com") {
                    showMostlySecurityWebsite()
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
    
        .defaultSize(width: 800, height: 600)
    }
    
    func openPodcastFile() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.mp3]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        let response = openPanel.runModal()
        return response == .OK ? openPanel.url : nil
    }
    
    func showMostlySecurityWebsite() {
        let address = "https://mostlysecurity.com"
        guard let url = URL(string: address) else {
            fatalError("Invalid URL: \(address)")
        }
        NSWorkspace.shared.open(url)
    }
}

