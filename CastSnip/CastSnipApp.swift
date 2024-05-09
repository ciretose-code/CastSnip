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
    
    @State var podcastAudioFile = AudioFile()

    @State var fileURL: URL = Bundle.main.url(forResource:"intro", withExtension: "mp3")!
    
    var body: some Scene {
        WindowGroup {
            ContentView().environment(podcastAudioFile)
                .frame(minWidth: 800, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
                .task {
                await podcastAudioFile.loadPodcast(from: fileURL)
            }
        }
        .onChange(of: fileURL) {
            print("onChange")
            Task.detached(priority: .high) {
                await podcastAudioFile.loadPodcast(from: fileURL)
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
                Button("Save As...") {
                    savePodcastFile()
                }
                .keyboardShortcut("S", modifiers: .command)
            }
            
            CommandGroup(before: .help){
                #if os(iOS)
                Link("mostlysecurity.com", destination: URL(string: "https://mostlysecurity.com")!)
                #else
                Button("mostlysecurity.com") {
                    showMostlySecurityWebsite()
                }
                .keyboardShortcut("/", modifiers: .command)
                #endif
            }
        }
    
        .defaultSize(width: 800, height: 600)
    }
    
    func openPodcastFile() -> URL? {
        #if os(iOS)
        return nil
        #else
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.mp3]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        let response = openPanel.runModal()
        return response == .OK ? openPanel.url : nil
        #endif
    }
    
    func savePodcastFile() {
        print("save podcast file")
    }
    
    func showMostlySecurityWebsite() {
        let address = "https://mostlysecurity.com"
        guard let url = URL(string: address) else {
            fatalError("Invalid URL: \(address)")
        }
        #if os(iOS)
        print(address)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

