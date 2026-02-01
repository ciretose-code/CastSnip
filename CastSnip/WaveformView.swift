//
//  WaveformView.swift
//  CastSnip
//
//  Created by AI Assistant on 1/31/26.
//

import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    let audioFile: AVAudioFile?
    let sampleCount: Int
    @State private var samples: [Float] = []
    @State private var isLoading = true
    @State private var audioDuration: TimeInterval = 0
    
    init(audioFile: AVAudioFile?, sampleCount: Int = 500) {
        self.audioFile = audioFile
        self.sampleCount = sampleCount
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isLoading {
                    ProgressView("Analyzing audio...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty {
                    Text("No audio data")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        Canvas { context, size in
                            drawWaveform(context: context, size: size)
                        }
                        .frame(height: 80)
                        
                        Canvas { context, size in
                            drawTimestamps(context: context, size: size)
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
        .frame(height: 100)
        .task {
            await loadSamples()
        }
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let midHeight = height / 2
        let barWidth = width / CGFloat(samples.count)
        let barSpacing: CGFloat = 0.5 // Minimal spacing for skinnier bars
        
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midHeight * 0.9 // 90% of available height
            
            let rect = CGRect(
                x: x,
                y: midHeight - barHeight / 2,
                width: max(barWidth - barSpacing, 1),
                height: max(barHeight, 1)
            )
            
            context.fill(
                Path(roundedRect: rect, cornerRadius: 0.5),
                with: .color(.accentColor)
            )
        }
        
        // Draw center line
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midHeight))
        path.addLine(to: CGPoint(x: width, y: midHeight))
        context.stroke(
            path,
            with: .color(.secondary.opacity(0.3)),
            lineWidth: 0.5
        )
    }
    
    private func drawTimestamps(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        
        guard audioDuration > 0 else { return }
        
        // Calculate appropriate interval based on duration
        let markerInterval: TimeInterval
        let markerCount: Int
        
        if audioDuration <= 60 {
            // Under 1 minute: every 10 seconds
            markerInterval = 10
            markerCount = Int(ceil(audioDuration / markerInterval)) + 1
        } else if audioDuration <= 300 {
            // 1-5 minutes: every 30 seconds
            markerInterval = 30
            markerCount = Int(ceil(audioDuration / markerInterval)) + 1
        } else if audioDuration <= 1800 {
            // 5-30 minutes: every 1 minute
            markerInterval = 60
            markerCount = Int(ceil(audioDuration / markerInterval)) + 1
        } else if audioDuration <= 3600 {
            // 30-60 minutes: every 5 minutes
            markerInterval = 300
            markerCount = Int(ceil(audioDuration / markerInterval)) + 1
        } else {
            // Over 1 hour: every 10 minutes
            markerInterval = 600
            markerCount = Int(ceil(audioDuration / markerInterval)) + 1
        }
        
        for i in 0..<markerCount {
            let timestamp = TimeInterval(i) * markerInterval
            if timestamp > audioDuration { break }
            
            let x = (timestamp / audioDuration) * width
            
            // Draw tick mark
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: 0))
            tickPath.addLine(to: CGPoint(x: x, y: 5))
            context.stroke(
                tickPath,
                with: .color(.secondary),
                lineWidth: 1
            )
            
            // Draw timestamp label
            let timeString = formatTimestamp(timestamp)
            let text = Text(timeString)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            context.draw(
                text,
                at: CGPoint(x: x, y: height - 5),
                anchor: .bottom
            )
        }
    }
    
    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func loadSamples() async {
        guard let audioFile = audioFile else {
            isLoading = false
            return
        }
        
        // Calculate audio duration
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        
        // Perform heavy computation off main thread
        let extractedSamples = await Task.detached(priority: .userInitiated) {
            extractAudioSamples(from: audioFile, targetSampleCount: sampleCount)
        }.value
        
        await MainActor.run {
            self.samples = extractedSamples
            self.audioDuration = duration
            self.isLoading = false
        }
    }
}

// MARK: - Audio Processing Helper
fileprivate func extractAudioSamples(from audioFile: AVAudioFile, targetSampleCount: Int) -> [Float] {
    let totalFrames = AVAudioFrameCount(audioFile.length)
    
    guard totalFrames > 0 else { return [] }
    
    let format = audioFile.processingFormat
    let channelCount = Int(format.channelCount)
    
    // Calculate how many frames to skip for each sample
    let frameStep = max(Int(totalFrames) / targetSampleCount, 1)
    
    var samples: [Float] = []
    
    // Read audio in chunks to avoid memory issues
    let chunkSize: AVAudioFrameCount = 4096
    var currentFrame: AVAudioFramePosition = 0
    
    var sampleIndex = 0
    var accumulatedSamples: [Float] = []
    
    while currentFrame < audioFile.length && samples.count < targetSampleCount {
        let framesToRead = min(chunkSize, AVAudioFrameCount(audioFile.length - currentFrame))
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: framesToRead
        ) else { break }
        
        audioFile.framePosition = currentFrame
        
        do {
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData else { continue }
            
            let frameCount = Int(buffer.frameLength)
            
            // Process frames in this chunk
            for frame in 0..<frameCount {
                // Mix all channels to mono by averaging
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frame]
                }
                let sample = sum / Float(channelCount)
                accumulatedSamples.append(abs(sample))
                
                sampleIndex += 1
                
                // When we've accumulated enough samples for one output sample
                if sampleIndex >= frameStep {
                    // Take the max of accumulated samples for this bucket
                    if let maxSample = accumulatedSamples.max() {
                        samples.append(maxSample)
                    }
                    accumulatedSamples.removeAll(keepingCapacity: true)
                    sampleIndex = 0
                    
                    if samples.count >= targetSampleCount {
                        break
                    }
                }
            }
            
        } catch {
            print("Error reading audio buffer: \(error)")
            break
        }
        
        currentFrame += AVAudioFramePosition(framesToRead)
    }
    
    // Normalize samples to 0...1 range
    if let maxValue = samples.max(), maxValue > 0 {
        samples = samples.map { $0 / maxValue }
    }
    
    return samples
}
