//
//  AudioEngineManager.swift
//  Chattie
//
//  Created by 村上晋太郎 on 2016/02/11.
//  Copyright © 2016年 R. Fushimi and S. Murakami. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

class AudioEngineManager: NSObject {
    
    private let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    
    private let pitch = AVAudioUnitTimePitch()
    private let mixer = AVAudioMixerNode() // ファイルフォーマットの不整合を吸収
    private let dist = AVAudioUnitDistortion()
    
    var recording = false
    var playing = false
    var analyzing = false

    var spectrum = [Float](count: 10000, repeatedValue: 0.0)

    var playerVolume: Float {
        get { return player.volume }
        set { player.volume = newValue }
    }

    var pitchshift: Float {
        get { return pitch.pitch }
        set { pitch.pitch = newValue }
    }

    var speed: Float {
        get { return pitch.rate }
        set { pitch.rate = newValue }
    }

    var cutofffreq: Float {
        get { return equalizer.bands.first!.frequency }
        set { equalizer.bands.first!.frequency = newValue }
    }
    
    var inputLevel:Double = 0.0
    var averageInputLevel:Double = 0.0

    var speechDetecting = false
    var concurrentSilentFrames = 0
    let equalizer = AVAudioUnitEQ(numberOfBands: 1)
    
    // 算出した基本周波数
    var targetf0 = 440.0

    var analyzedf0 = 110.0
    var analyzedPitchshift = 2400.0
    var analyzingMutex = false

    var pitchDetectionInputLevelThreshold = 0.0005
    

    var speechDetectionOnInputLevelThreshold = 0.0002
    var speechDetectionOffInputLevelThreshold: Double {
        get {
            return speechDetectionOnInputLevelThreshold * 0.5
        }
    }
    let speechDetectionOffConcurrentFramesThreshold = 3
        weak var speechDetectionDelegate: AudioEngineManagerSpeechDetectionDelegate? = nil
    
    var fileForRecording: AVAudioFile?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupEngine()
    }
    
    func setupEngine() {
        guard let input = engine.inputNode else {
            AppUtil.alert("ERROR", message: "input node not found")
            return
        }

        let bands = equalizer.bands
        let param = bands.first!
        param.filterType = .LowPass
        param.frequency = 22000
        param.bypass = false
        
        let format = input.outputFormatForBus(0)

        engine.attachNode(player)
        engine.attachNode(mixer)
        engine.attachNode(dist)
        engine.attachNode(pitch)
        engine.attachNode(equalizer)
        
        playerVolume = 1.0
        engine.connect(player, to: mixer, format: format)
        engine.connect(mixer, to: pitch, format: nil)
        engine.connect(pitch, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)
        engine.connect(input, to: engine.mainMixerNode, format: format)
        input.volume = 0
        startEngine()
        
        // attach tap to update input volume
        // for waveform visualization and speech detection
        let bus = 0
        let size: AVAudioFrameCount = 4096 // 0.1sec?
        input.installTapOnBus(bus, bufferSize: size, format: nil) {
            (AVAudioPCMBuffer buffer, AVAudioTime when) in
            self.updateInputLevel(buffer, when: when)
            if self.recording {
                self.updateRecording(buffer, when: when)
            }
            if self.analyzing {
                self.updateAnalyzing(buffer, when: when)
            }
//            NSLog("frameLength: %d", buffer.frameLength)
            buffer.frameLength = size
        }
    }
    
    func updateInputLevel(buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        let frameLength = 2048 // bufferのlengthを書き換えたら副作用がありそうだから念のため...
        self.inputLevel = 0.0
        for i in 0 ..< Int(frameLength) {
            self.inputLevel += pow(Double(buffer.floatChannelData.memory[i]), 2)
        }
        self.inputLevel /= Double(frameLength)
        self.inputLevelUpdated()
    }
    
    func startAnalyzing() {
        self.analyzing = true
    }
    func stopAnalyzing() {
        self.analyzing = false
    }
    
    func inputLevelUpdated() {
        if inputLevel > 1.0 {
            inputLevel = 1.0
        }
        
        if !speechDetecting{
            if inputLevel > speechDetectionOnInputLevelThreshold {
                speechDetecting = true
                if let delegate = speechDetectionDelegate {
                    delegate.audioEngineManagerDidStartSpeechDetection(self)
                }
            }
        }else{
            if inputLevel < speechDetectionOffInputLevelThreshold {
                concurrentSilentFrames += 1
            } else {
                concurrentSilentFrames = 0
            }
            if concurrentSilentFrames > speechDetectionOffConcurrentFramesThreshold {
                speechDetecting = false
                concurrentSilentFrames = 0
                if let delegate = speechDetectionDelegate {
                    delegate.audioEngineManagerDidFinishSpeechDetection(self)
                }
            }
        }
    }
    
    func updateRecording(buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        guard let file = fileForRecording else {
            NSLog("ERROR: file for recording is nil")
            return
        }
        do {
            try file.writeFromBuffer(buffer)
        } catch {
            NSLog("ERROR: recording to audio file failed")
            print(error)
        }
    }

    func updateAnalyzing(buffer: AVAudioPCMBuffer, when: AVAudioTime) {
        if inputLevel < pitchDetectionInputLevelThreshold {
            return
        }
        if analyzingMutex {
            return
        }
        analyzingMutex = true

        let bufferSize: Int = Int(buffer.frameLength)

        // Set up the transform
        let log2n = UInt(round(log2(Double(bufferSize))))
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        // Create the complex split value to hold the output of the transform
        var realp = [Float](count: bufferSize/2, repeatedValue: 0)
        var imagp = [Float](count: bufferSize/2, repeatedValue: 0)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)

        var channelSamples: [DSPComplex] = []
        let firstSample = 0
        for var j=firstSample; j<bufferSize; j+=buffer.stride {
            channelSamples.append(DSPComplex(real: buffer.floatChannelData.memory[j], imag: 0.0))
        }
        vDSP_ctoz(channelSamples, 2, &output, 1, UInt(bufferSize / 2))
        
        // Do the fast Fournier forward transform
        vDSP_fft_zrip(fftSetup, &output, 1, log2n, Int32(FFT_FORWARD))

        // Convert the complex output to magnitude
        var mag = [Float](count:Int(bufferSize / 2), repeatedValue:0.0)
        vDSP_zvmags(&output, 1, &mag, 1, vDSP_Length(bufferSize / 2))

        channelSamples = []
        for var j=0; j<bufferSize/2; j+=buffer.stride {
            channelSamples.append(DSPComplex(real: mag[j], imag: 0.0))
        }

        vDSP_ctoz(channelSamples, 2, &output, 1, UInt(bufferSize / 2))
        vDSP_fft_zrip(fftSetup, &output, 1, log2n, Int32(FFT_INVERSE))
        
        var autocorr_z = [DSPComplex](count: bufferSize/2, repeatedValue: DSPComplex(real: 0.0, imag: 0.0))
        vDSP_ztoc(&output, 1, &autocorr_z, 2, vDSP_Length(bufferSize/2));
        
        var autocorr = [Float](count: bufferSize/2, repeatedValue: 0)
        for var i = 0; i < bufferSize/2; i++ {
            autocorr[i] = autocorr_z[i].real
            if autocorr[0] != 0 {
                autocorr[i] = autocorr[i] / autocorr[0]
            }
        }

        for var i = 0; i < bufferSize/2; i++ {
            autocorr[i] = autocorr[i] / autocorr[1]
        }

        var peak = false
        var peakval: [Float] = [0.0]
        var peakbin: [Int] = [0]
        var peakbinK = 0

        for var i = 44100/600; i < 44100/50; i++ {
            if peak {
                if autocorr[i] > peakval[peakbinK] {
                    peakval[peakbinK] = autocorr[i]
                    peakbin[peakbinK] = i
                }
                if autocorr[i] < 0 {
                    peak = false
                    peakbinK += 1
                    peakval.append(0.0)
                    peakbin.append(0)
                }
            }else{
                if autocorr[i] > 0 {
                    peak = true
                }
            }
        }
        
        let peakss = peakval.maxElement() ?? 0
        let peakt = ({() -> Int in
            for var i = 0; i < peakbinK; i++ {
//                NSLog("peakfreq = %4.1f, strength = %0.4f (peakss = %f)", 44100.0 / Double(peakbin[i]), peakval[i] / peakss, peakss)
                if peakval[i] > peakss * 0.8 {
                    return peakbin[i]
                }
            }
            return 1
        })()
        
        if peakt != 44100/50 && speechDetecting {
            var freq: Double = 44100.0 / Double(peakt)
            NSLog("freq = %4.1f", freq)
            analyzedf0 += (freq - analyzedf0) * 0.4
            analyzedPitchshift = log2(440 / analyzedf0) * Double(1200)
        }
    
        spectrum = autocorr
        vDSP_destroy_fftsetup(fftSetup)
        analyzingMutex = false
    }

    
    func startEngine() {
        if !engine.running {
            do {
                try engine.start()
            } catch {
                AppUtil.alert("ERROR", message: "could not start audio engine")
            }
        }
    }
    
    // MARK: - Play and Record
    
    func startRecording(fileURL: NSURL) {
        startEngine()
        
        guard let input = engine.inputNode else {
            AppUtil.alert("ERROR", message: "input node not found")
            return
        }
        
        // setup audio file
        let bus = 0
        guard let file = try? AVAudioFile(forWriting: fileURL,settings: input.outputFormatForBus(bus).settings) else {
            AppUtil.alert("ERROR", message: "creating audio file for recording failed")
            return
        }
        
        fileForRecording = file
        recording = true
    }
    
    func stopRecording() {
        if recording {
            recording = false
            fileForRecording = nil
        }
    }
    
    let defaultPitch: Float = 2000
    func startPlaying(fileURL: NSURL, completion: (() -> Void)? = nil) {
        startPlaying(fileURL, pitchShinfted: false, completion: completion)
    }
    
    func startPlaying(fileURL: NSURL, pitchShinfted: Bool, completion: (() -> Void)? = nil) {
        stopPlaying()
        guard let file = try? AVAudioFile(forReading: fileURL) else {
            AppUtil.alert("ERROR", message: "reading recording file failed")
            return
        }
        let buffer = AVAudioPCMBuffer(PCMFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        do {
            try file.readIntoBuffer(buffer)
        } catch {
            AppUtil.alert("ERROR", message: "can not read file")
        }
//        if pitchShinfted {
//            pitch.pitch = defaultPitch
//        } else {
//            pitch.pitch = 0
//        }
        
        // フォーマット変更
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: mixer, format: buffer.format)
        
        startEngine()
        player.scheduleBuffer(buffer, atTime: nil, options: AVAudioPlayerNodeBufferOptions.Interrupts, completionHandler: {
            if let comp = completion {
                comp()
            }
            self.playing = false
        })
        player.play()
        playing = true
    }
    
    func stopPlaying() {
        if player.playing {
            player.stop()
        }
    }
    
    static let shared = AudioEngineManager()
    class func setup() {
        let _ = shared
    }
}

@objc protocol AudioEngineManagerSpeechDetectionDelegate {
    func audioEngineManagerDidStartSpeechDetection(manager: AudioEngineManager)
    func audioEngineManagerDidFinishSpeechDetection(manager: AudioEngineManager)
}
