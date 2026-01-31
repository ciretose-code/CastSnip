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
    
    init(audioFile: AVAudioFile?, sampleCount: Int = 200) {
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
                    Canvas { context, size in
                        drawWaveform(context: context, size: size)
                    }
                    .frame(height: 80)
                }
            }
        }
        .frame(height: 80)
        .task {
            await loadSamples()
        }
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let midHeight = height / 2
        let barWidth = width / CGFloat(samples.count)
        
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midHeight * 0.9 // 90% of available height
            
            let rect = CGRect(
                x: x,
                y: midHeight - barHeight / 2,
                width: max(barWidth - 1, 1),
                height: max(barHeight, 1)
            )
            
            context.fill(
                Path(roundedRect: rect, cornerRadius: 1),
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
    
    private func loadSamples() async {
        guard let audioFile = audioFile else {
            isLoading = false
            return
        }
        
        // Perform heavy computation off main thread
        let extractedSamples = await Task.detached(priority: .userInitiated) {
            return self.extractAudioSamples(from: audioFile, targetSampleCount: sampleCount)
        }.value
        
        await MainActor.run {
            self.samples = extractedSamples
            self.isLoading = false
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
}

/*
#Preview("Waveform with Sample") {
    struct WaveformTestView: View {
        let audioFile: AVAudioFile?
        
        init() {
            if let url = Bundle.main.url(forResource: "intro", withExtension: "mp3") {
                audioFile = try? AVAudioFile(forReading: url)
            } else {
                audioFile = nil
            }
        }
        
        var body: some View {
            VStack {
                Text("Waveform Preview")
                    .font(.headline)
                WaveformView(audioFile: audioFile, sampleCount: 150)
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            }
            .padding()
        }
    }
    
    return WaveformTestView()
}

#Preview("Waveform Empty") {
    WaveformView(audioFile: nil, sampleCount: 150)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
}

*/
