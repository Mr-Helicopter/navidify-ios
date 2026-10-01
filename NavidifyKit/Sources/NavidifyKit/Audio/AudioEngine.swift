import Foundation
import AVFoundation
import Observation

public enum PlaybackState: Sendable {
    case stopped
    case loading
    case playing
    case paused
    case error(String)
}

public enum RepeatMode: String, CaseIterable, Sendable {
    case off = "off"
    case all = "all"
    case one = "one"
}

@Observable
public final class AudioEngine: @unchecked Sendable {
    public static let shared = AudioEngine()

    // MARK: - Observable State
    public private(set) var currentSong: Song? {
        didSet {
            onTrackChange?(currentSong)
            var info: [String: Any] = [:]
            if let song = currentSong {
                info["song"] = song
            }
            NotificationCenter.default.post(
                name: .audioEngineTrackDidChange,
                object: self,
                userInfo: info
            )
        }
    }
    public private(set) var playbackState: PlaybackState = .stopped {
        didSet {
            onStateChange?(playbackState)
            NotificationCenter.default.post(
                name: .audioEnginePlaybackStateDidChange,
                object: self,
                userInfo: ["playbackState": playbackState]
            )
        }
    }
    public private(set) var currentTime: Double = 0.0
    public private(set) var duration: Double = 0.0
    public private(set) var isBuffering: Bool = false
    public var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }
    public var isMuted: Bool = false {
        didSet {
            engine.mainMixerNode.outputVolume = isMuted ? 0 : volume
        }
    }

    // Queue & Playback Modes
    public var queue: [Song] = []
    public var queueIndex: Int = 0
    public var isShuffle: Bool = false
    public var repeatMode: RepeatMode = .off

    // Equalizer
    public var isEQEnabled: Bool = true {
        didSet {
            updateEQGains()
        }
    }
    public var selectedPresetName: String = "Flat" {
        didSet {
            if let preset = EQPresetConstants.presets[selectedPresetName] {
                eqGains = preset.gains
            }
        }
    }
    public var eqGains: [Float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] {
        didSet {
            updateEQGains()
        }
    }

    // Callbacks for Lock Screen / MPRemoteCommandCenter
    public var onTrackChange: (@Sendable (Song?) -> Void)?
    public var onStateChange: (@Sendable (PlaybackState) -> Void)?
    public var onProgressUpdate: (@Sendable (Double, Double) -> Void)?

    // MARK: - Core Audio Units
    private let engine = AVAudioEngine()
    private let playerNodeA = AVAudioPlayerNode()
    private let playerNodeB = AVAudioPlayerNode()
    private let preEQMixer = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var activeSlot: ActiveSlot = .slotA

    private enum ActiveSlot {
        case slotA
        case slotB

        var other: ActiveSlot {
            self == .slotA ? .slotB : .slotA
        }
    }

    // Audio streaming & spooling state
    private var currentAudioFile: AVAudioFile?
    private var currentTempFileUrl: URL?
    private var currentDownloadTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var scheduledFrames: AVAudioFramePosition = 0
    private var totalFramesRead: AVAudioFramePosition = 0
    private var audioFormat: AVAudioFormat?
    private var sampleRate: Double = 44100.0

    private var isStreamComplete = false
    private var activeBuffersCount: Int = 0
    private var playbackGeneration: Int = 0
    private var isTransitioningTrack = false

    private var timeObserverTimer: Timer?
    private var preloadTriggered = false
    private var seekOffset: Double = 0.0
    private let lock = NSRecursiveLock()

    private init() {
        setupAudioSession()
        setupAudioGraph()
        #if os(iOS)
        setupAudioSessionObservers()
        #endif
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioEngine] Failed to set up AVAudioSession: \(error)")
        }
        #endif
    }

    #if os(iOS)
    private var wasPlayingBeforeInterruption = false

    private func setupAudioSessionObservers() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification: notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionRouteChange(notification: notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
    }

    private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if case .playing = playbackState {
                wasPlayingBeforeInterruption = true
                pause()
            } else {
                wasPlayingBeforeInterruption = false
            }
        case .ended:
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }

    private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            // Unplugged headphones / disconnected Bluetooth car audio: Apple HIG requires pausing
            if case .playing = playbackState {
                pause()
            }
        }
    }

    private func handleMediaServicesReset() {
        print("[AudioEngine] Audio media services reset. Rebuilding graph...")
        setupAudioSession()
        setupAudioGraph()
    }
    #endif

    private func setupAudioGraph() {
        engine.attach(playerNodeA)
        engine.attach(playerNodeB)
        engine.attach(preEQMixer)
        engine.attach(eqNode)

        // Configure 10-band EQ frequencies matching web app
        for i in 0..<10 {
            let band = eqNode.bands[i]
            band.frequency = EQPresetConstants.frequencies[i]
            band.bypass = false
            if i == 0 {
                band.filterType = .lowShelf
            } else if i == 9 {
                band.filterType = .highShelf
            } else {
                band.filterType = .parametric
                band.bandwidth = 1.0
            }
            band.gain = 0
        }

        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0
        let channelCount = outputFormat.channelCount > 0 ? outputFormat.channelCount : 2
        let canonicalFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)!

        // Connect both player nodes to preEQMixer (AVAudioMixerNode accepts multiple inputs)
        engine.connect(playerNodeA, to: preEQMixer, format: canonicalFormat)
        engine.connect(playerNodeB, to: preEQMixer, format: canonicalFormat)

        // Connect mixer -> EQ -> mainMixerNode
        engine.connect(preEQMixer, to: eqNode, format: canonicalFormat)
        engine.connect(eqNode, to: engine.mainMixerNode, format: canonicalFormat)

        do {
            try engine.start()
        } catch {
            print("[AudioEngine] Engine start failed: \(error)")
        }
    }

    private func updateEQGains() {
        for (i, gain) in eqGains.enumerated() where i < 10 {
            eqNode.bands[i].bypass = !isEQEnabled
            eqNode.bands[i].gain = isEQEnabled ? gain : 0
        }
    }

    // MARK: - Playback Control

    public func play(song: Song) {
        lock.lock()
        defer { lock.unlock() }

        playbackGeneration += 1
        activeBuffersCount = 0
        isStreamComplete = false
        isTransitioningTrack = false

        // Stop and reset player nodes from previous track
        activePlayerNode.stop()
        inactivePlayerNode.stop()
        activePlayerNode.reset()
        inactivePlayerNode.reset()

        self.currentSong = song
        self.currentTime = 0.0
        self.seekOffset = 0.0
        self.duration = song.duration
        self.preloadTriggered = false
        self.playbackState = .loading
        self.isBuffering = true

        onTrackChange?(song)
        onStateChange?(.loading)

        Task {
            if let streamUrl = await NavidromeClient.shared.getStreamUrl(songId: song.id) {
                self.startStreaming(url: streamUrl, song: song)
            } else {
                await MainActor.run {
                    self.playbackState = .error("Failed to resolve stream URL")
                    self.isBuffering = false
                    self.onStateChange?(self.playbackState)
                }
            }
        }
    }

    public func playQueue(songs: [Song], startIndex: Int = 0) {
        guard !songs.isEmpty, startIndex >= 0, startIndex < songs.count else { return }
        self.queue = songs
        self.queueIndex = startIndex
        play(song: songs[startIndex])
    }

    public func resume() {
        guard currentSong != nil else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        activePlayerNode.play()
        playbackState = .playing
        isBuffering = false
        startTimeTimer()
        onStateChange?(.playing)
    }

    public func pause() {
        activePlayerNode.pause()
        playbackState = .paused
        stopTimeTimer()
        onStateChange?(.paused)
    }

    public func togglePlayPause() {
        if case .playing = playbackState {
            pause()
        } else {
            resume()
        }
    }

    public func next() {
        guard !queue.isEmpty else { return }
        if repeatMode == .one {
            seek(to: 0)
            return
        }

        var nextIndex = queueIndex + 1
        if nextIndex >= queue.count {
            if repeatMode == .all {
                nextIndex = 0
            } else {
                stop()
                return
            }
        }
        queueIndex = nextIndex
        play(song: queue[queueIndex])
    }

    public func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        var prevIndex = queueIndex - 1
        if prevIndex < 0 {
            prevIndex = (repeatMode == .all) ? queue.count - 1 : 0
        }
        queueIndex = prevIndex
        play(song: queue[queueIndex])
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        playbackGeneration += 1
        activeBuffersCount = 0
        isStreamComplete = false
        isTransitioningTrack = false

        stopTimeTimer()
        activePlayerNode.stop()
        inactivePlayerNode.stop()
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        cleanupTempFile()

        playbackState = .stopped
        currentTime = 0
        seekOffset = 0
        isBuffering = false
        onStateChange?(.stopped)
    }

    public func seek(to seconds: Double) {
        lock.lock()
        defer { lock.unlock() }

        guard currentSong != nil, let tempUrl = currentTempFileUrl else { return }

        // Reopen audio file to query latest available length on disk
        guard let audioFile = try? AVAudioFile(forReading: tempUrl) else { return }
        self.currentAudioFile = audioFile

        let fileDuration = Double(audioFile.length) / sampleRate
        let maxSeekable = isStreamComplete ? max(fileDuration, duration) : fileDuration
        let clampedSeconds = max(0, min(seconds, max(0, maxSeekable - 0.25)))
        let targetFrame = AVAudioFramePosition(clampedSeconds * sampleRate)

        let wasPlaying = (playbackState == .playing)

        activePlayerNode.stop()
        activePlayerNode.reset()

        playbackGeneration += 1
        activeBuffersCount = 0

        self.seekOffset = clampedSeconds
        self.currentTime = clampedSeconds
        self.scheduledFrames = min(targetFrame, audioFile.length)

        scheduleNextBuffers()

        if wasPlaying {
            if !engine.isRunning {
                try? engine.start()
            }
            activePlayerNode.play()
            self.playbackState = .playing
        }

        self.onProgressUpdate?(self.currentTime, self.duration)
        NotificationCenter.default.post(
            name: .audioEngineProgressDidUpdate,
            object: self,
            userInfo: ["currentTime": self.currentTime, "duration": self.duration]
        )
    }

    // MARK: - Streaming & Buffer Pipeline

    private var activePlayerNode: AVAudioPlayerNode {
        activeSlot == .slotA ? playerNodeA : playerNodeB
    }

    private var inactivePlayerNode: AVAudioPlayerNode {
        activeSlot == .slotA ? playerNodeB : playerNodeA
    }

    private func startStreaming(url: URL, song: Song) {
        cleanupTempFile()

        let tempDir = FileManager.default.temporaryDirectory
        let tempUrl = tempDir.appendingPathComponent("navidify_stream_\(UUID().uuidString).\(song.suffix ?? "mp3")")
        FileManager.default.createFile(atPath: tempUrl.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: tempUrl) else {
            DispatchQueue.main.async {
                self.playbackState = .error("Failed to create stream spool")
                self.isBuffering = false
            }
            return
        }

        lock.lock()
        self.currentTempFileUrl = tempUrl
        self.fileHandle = handle
        self.scheduledFrames = 0
        self.totalFramesRead = 0
        self.activeBuffersCount = 0
        self.isStreamComplete = false
        lock.unlock()

        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0

        let delegate = StreamDataDelegate { [weak self] data in
            self?.didReceiveStreamChunk(data)
        } onComplete: { [weak self] error in
            self?.didCompleteStream(error: error)
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        self.currentDownloadTask = task
        task.resume()
    }

    private func didReceiveStreamChunk(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = fileHandle else { return }
        do {
            try handle.write(contentsOf: chunk)
            try? handle.synchronize()
        } catch {
            return
        }

        // Initialize audio file once sufficient data is spooled (> 64KB)
        if currentAudioFile == nil, let tempUrl = currentTempFileUrl {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: tempUrl.path)[.size] as? UInt64) ?? 0
            if fileSize > 65536 {
                if let file = try? AVAudioFile(forReading: tempUrl) {
                    self.currentAudioFile = file
                    self.audioFormat = file.processingFormat
                    self.sampleRate = file.processingFormat.sampleRate

                    // Dynamically connect activePlayerNode with file's format to match buffer format
                    self.engine.disconnectNodeOutput(self.activePlayerNode)
                    self.engine.connect(self.activePlayerNode, to: self.preEQMixer, format: file.processingFormat)

                    scheduleNextBuffers()

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        guard case .loading = self.playbackState else { return }
                        if !self.engine.isRunning {
                            try? self.engine.start()
                        }
                        self.activePlayerNode.play()
                        self.playbackState = .playing
                        self.isBuffering = false
                        self.startTimeTimer()
                        self.onStateChange?(.playing)
                    }
                }
            }
        } else if currentAudioFile != nil {
            scheduleNextBuffers()
        }
    }

    private func scheduleNextBuffers(isFinal: Bool = false) {
        lock.lock()
        defer { lock.unlock() }

        guard let tempUrl = currentTempFileUrl else { return }

        // If we already have 30s buffered ahead, avoid disk I/O unless forced final
        let playedFrames = AVAudioFramePosition(currentTime * sampleRate)
        let maxLookahead = AVAudioFramePosition(sampleRate * 30.0) // 30s rolling lookahead
        let currentBuffered = scheduledFrames - playedFrames
        if currentBuffered >= maxLookahead && !isFinal {
            return
        }

        guard let file = try? AVAudioFile(forReading: tempUrl) else { return }
        self.currentAudioFile = file

        let currentLength = file.length
        guard currentLength > 0 else { return }

        let chunkFrames = AVAudioFramePosition(sampleRate * 5.0) // 5-second buffer chunks
        let currentGen = self.playbackGeneration

        while scheduledFrames < currentLength {
            let bufferedAhead = scheduledFrames - playedFrames
            if bufferedAhead >= maxLookahead && !isFinal {
                break
            }

            let unreadFrames = currentLength - scheduledFrames
            let minThreshold: AVAudioFramePosition = (scheduledFrames == 0) ? AVAudioFramePosition(sampleRate * 0.5) : (isFinal ? 1 : chunkFrames)
            if unreadFrames < minThreshold && !isFinal {
                break
            }

            let framesToRead = AVAudioFrameCount(min(unreadFrames, chunkFrames))
            if framesToRead == 0 { break }

            file.framePosition = scheduledFrames
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesToRead) else {
                break
            }

            do {
                try file.read(into: buffer)
                activeBuffersCount += 1
                activePlayerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                    self?.handleBufferCompleted(generation: currentGen)
                }
                scheduledFrames += AVAudioFramePosition(buffer.frameLength)
            } catch {
                break
            }
        }

        // Buffer starvation recovery: if playing state but node stopped due to buffer starvation
        if playbackState == .playing && !activePlayerNode.isPlaying && scheduledFrames > playedFrames {
            if !engine.isRunning {
                try? engine.start()
            }
            activePlayerNode.play()
        }
    }

    private func handleBufferCompleted(generation: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            // Stale generation from previous track or seek
            guard self.playbackGeneration == generation else { return }
            self.activeBuffersCount = max(0, self.activeBuffersCount - 1)

            // Track completion: stream finished, all frames scheduled, and all buffers rendered
            if self.isStreamComplete,
               let file = self.currentAudioFile,
               self.scheduledFrames >= file.length,
               self.activeBuffersCount == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.handleTrackFinished()
                }
                return
            }

            // Continuous replenishment
            self.scheduleNextBuffers()
        }
    }

    private func handleTrackFinished() {
        guard !isTransitioningTrack, playbackState != .stopped else { return }
        isTransitioningTrack = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isTransitioningTrack = false
            }
        }

        if repeatMode == .one {
            seek(to: 0)
        } else {
            next()
        }
    }

    private func didCompleteStream(error: Error?) {
        lock.lock()
        defer { lock.unlock() }

        guard error == nil, let tempUrl = currentTempFileUrl else { return }
        try? fileHandle?.synchronize()
        self.isStreamComplete = true

        if let file = try? AVAudioFile(forReading: tempUrl) {
            self.currentAudioFile = file
            let exactDuration = Double(file.length) / file.processingFormat.sampleRate
            if exactDuration > 0 {
                self.duration = exactDuration
            }
        }

        scheduleNextBuffers(isFinal: true)
    }

    private func startTimeTimer() {
        stopTimeTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.handleTimeTick()
            }
        }
    }

    private func stopTimeTimer() {
        DispatchQueue.main.async {
            self.timeObserverTimer?.invalidate()
            self.timeObserverTimer = nil
        }
    }

    private func handleTimeTick() {
        guard case .playing = playbackState, let nodeTime = activePlayerNode.lastRenderTime,
              let playerTime = activePlayerNode.playerTime(forNodeTime: nodeTime) else {
            return
        }

        let playedSeconds = seekOffset + (Double(playerTime.sampleTime) / sampleRate)
        if playedSeconds >= 0 {
            self.currentTime = min(playedSeconds, duration)
            self.onProgressUpdate?(self.currentTime, self.duration)
            NotificationCenter.default.post(
                name: .audioEngineProgressDidUpdate,
                object: self,
                userInfo: ["currentTime": self.currentTime, "duration": self.duration]
            )

            // Maintain rolling buffer ahead of playhead (15s minimum lookahead)
            let playedFrames = AVAudioFramePosition(currentTime * sampleRate)
            let bufferedAhead = scheduledFrames - playedFrames
            if bufferedAhead < AVAudioFramePosition(sampleRate * 15.0) {
                scheduleNextBuffers()
            }

            // Web app parity: Preload next track when 15 seconds remain
            if duration > 15 && (duration - currentTime) <= 15 && !preloadTriggered {
                preloadTriggered = true
                preloadNextTrack()
            }

            // Fallback track finished check if duration reached
            if duration > 0 && currentTime >= (duration - 0.5) {
                handleTrackFinished()
            }
        }
    }

    private func preloadNextTrack() {
        let nextIndex = queueIndex + 1
        if nextIndex < queue.count {
            let nextSong = queue[nextIndex]
            Task {
                if let streamUrl = await NavidromeClient.shared.getStreamUrl(songId: nextSong.id) {
                    // Prewarm HTTP connection / cache for next track
                    var req = URLRequest(url: streamUrl)
                    req.httpMethod = "HEAD"
                    _ = try? await URLSession.shared.data(for: req)
                }
            }
        }
    }

    private func cleanupTempFile() {
        lock.lock()
        defer { lock.unlock() }

        fileHandle?.closeFile()
        fileHandle = nil
        if let url = currentTempFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
        currentTempFileUrl = nil
        currentAudioFile = nil
        isStreamComplete = false
        activeBuffersCount = 0
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let audioEngineTrackDidChange = Notification.Name("audioEngineTrackDidChange")
    public static let audioEnginePlaybackStateDidChange = Notification.Name("audioEnginePlaybackStateDidChange")
    public static let audioEngineProgressDidUpdate = Notification.Name("audioEngineProgressDidUpdate")
}

// MARK: - Stream Delegate Helper

private final class StreamDataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onData: @Sendable (Data) -> Void
    private let onComplete: @Sendable (Error?) -> Void

    init(onData: @escaping @Sendable (Data) -> Void, onComplete: @escaping @Sendable (Error?) -> Void) {
        self.onData = onData
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete(error)
    }
}
