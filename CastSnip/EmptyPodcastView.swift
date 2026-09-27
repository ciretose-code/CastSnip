//
//  EmptyPodcastView.swift
//  CastSnip
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct EmptyPodcastView: View {
    @Environment(\.openPodcast) private var openPodcast
    @Environment(\.openPodcastPanel) private var openPodcastPanel
    @State private var isDraggingAudio = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(EmptyEditorCopy.title)
                .font(.title2)
            Text(EmptyEditorCopy.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Open...") {
                openPodcastPanel()
            }
            .keyboardShortcut("o")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .onDrop(of: [.mp3, .wav, .aiff, .mpeg4Audio, .audio], isTargeted: $isDraggingAudio) { providers in
            handleAudioDrop(providers: providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .padding(16)
                .opacity(isDraggingAudio ? 0.7 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(EditorAccessibility.emptyEditor)
        .accessibilityLabel(EmptyEditorCopy.title)
        .accessibilityHint(EmptyEditorCopy.detail)
    }

    private func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let types = ["public.mp3", "public.wav", "public.aiff-audio", "public.mpeg-4-audio", "public.audio"]
        guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            if let url = item as? URL {
                DispatchQueue.main.async {
                    openPodcast(url)
                }
            }
        }
        return true
    }
}
