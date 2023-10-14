//
//  AudioVisualService.swift
//  AudioToTextPlayer
//
//  Created by Ian on 14/10/2023.
//

import Speech
import SwiftUI
import AVKit
import Combine

public class AudioVisualService: ObservableObject {
    
    public var player = AVPlayer()
    private let itemURL: String
    private var playerInitialised: Bool = false
    private var audioMixisReady: Bool = false
    private var speechRecognizerInitialised: Bool = false
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechRecognizer: SFSpeechRecognizer?
    private var tap: AudioTapProcessor!
    private var subscriptions: Set<AnyCancellable> = []
    private var playSatus: AVPlayer.TimeControlStatus = .waitingToPlayAtSpecifiedRate
    @Published public var transcribedText: String = ""
    
    @Published public var isPlaying: Bool = true {
        didSet {
            isPlaying ? play() : pause()
        }
    }
    
    public init(itemURL: String) {
        self.itemURL = itemURL
        
        SFSpeechRecognizer.requestAuthorization { status in
            print(status.rawValue)
        }
    }
    
    deinit {
        print("deinit")
        resetRecognition()
    }
    
    private func play() {
        DispatchQueue(label: "com.iankoex.audioVisualService", qos: .userInteractive).async { [self] in
            guard let url = URL(string: itemURL) else { return }
            guard self.playerInitialised == false else {
                player.play()
                setupRecognition()
                return
            }
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: playerItem)
            player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            player.automaticallyWaitsToMinimizeStalling = true
            player.allowsExternalPlayback = true
            player.playImmediately(atRate: 0)
            playerInitialised = true
            
            player.publisher(for: \.timeControlStatus)
                .sink { [weak self] status in
                    self?.updatePlayState(with: status)
                }
                .store(in: &subscriptions)
            
            if isPlaying {
                player.play()
            }
            
            if #available(macOS 12.0, iOS 15.0, *) {
                asset.loadTracks(withMediaType: .audio) { [self] tracks, _ in
                    guard let audioTrack = tracks?.first else {
                        return
                    }
                    tap = AudioTapProcessor(player: player, audioAssetTrack: audioTrack, delegate: self)
                    audioMixisReady = true
                    setupRecognition()
                }
            } else {
                guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
                    return
                }
                tap = AudioTapProcessor(player: player, audioAssetTrack: audioTrack, delegate: self)
                audioMixisReady = true
                setupRecognition()
            }
        }
    }
    
    private func pause() {
        player.pause()
        resetRecognition()
    }
    
    private func updatePlayState(with status: AVPlayer.TimeControlStatus) {
        playSatus = status
        setupRecognition()
    }
    
    private func setupRecognition() {
        guard audioMixisReady, isPlaying, playSatus == .playing else {
            return
        }
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer()
        }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        // we want to get continuous recognition and not everything at once at the end of the video
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
            guard let result = result, let self = self else { return }
            
            self.transcribedText = result.bestTranscription.formattedString
            // once in about every minute recognition task finishes so we need to set up a new one to continue recognition
            if result.isFinal == true {
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.setupRecognition()
            }
        }
        self.recognitionRequest = recognitionRequest
        speechRecognizerInitialised = true
    }
    
    private func resetRecognition() {
        recognitionTask = nil
        recognitionRequest = nil
    }
}

extension AudioVisualService: AudioTapProcessorDelegate {
    // getting audio buffer back from the tap and feeding into speech recognizer
    public func audioTabProcessor(didReceive buffer: CMSampleBuffer) {
        guard audioMixisReady, isPlaying, playSatus == .playing else {
            return
        }
        recognitionRequest?.appendAudioSampleBuffer(buffer)
    }
}
