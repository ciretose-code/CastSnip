//
//  Menus.swift
//  CastSnip
//
//  Created by Eric Wuehler on 4/27/24.
//

import SwiftUI

struct Menus: Commands {
    var body: some Commands {
        
        CommandGroup(replacing: .newItem) {
            
        }
        
        
        CommandGroup(after: .newItem) {
            Button("Open...") {
                let url = openPodcastFile()
                print("URL: \(String(describing: url))")
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
