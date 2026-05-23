import Cocoa
import Foundation

class MediaRemoteAdapter {
    typealias InfoCallback = ([String: Any]) -> Void
    typealias PlaybackStateCallback = (Int) -> Void

    var onTrackInfoReceived: InfoCallback?
    var onPlaybackStateReceived: PlaybackStateCallback?

    private var listeningProcess: Process?
    private var dataBuffer = Data()

    init() {}

    // MARK: - Resource discovery

    private var perlScriptPath: String? {
        Bundle.main.path(forResource: "run", ofType: "pl")
    }

    private var libraryPath: String? {
        guard let frameworksPath = Bundle.main.privateFrameworksPath else { return nil }
        let path = (frameworksPath as NSString).appendingPathComponent("MediaRemoteMRBridge.dylib")
        guard FileManager.default.fileExists(atPath: path) else {
            AppLog.error("[MediaRemoteAdapter] dylib not found at \(path)")
            return nil
        }
        return path
    }

    // MARK: - Listening

    func startListening() {
        guard listeningProcess == nil else { return }
        guard let scriptPath = perlScriptPath else {
            AppLog.error("[MediaRemoteAdapter] run.pl not found in bundle")
            return
        }
        guard let libraryPath = libraryPath else {
            AppLog.error("[MediaRemoteAdapter] MediaRemoteMRBridge.dylib not found in Frameworks")
            return
        }

        AppLog.info("[MediaRemoteAdapter] Starting subprocess: perl \(scriptPath) \(libraryPath) loop")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, libraryPath, "loop"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let incomingData = handle.availableData
            if incomingData.isEmpty { return }
            self.dataBuffer.append(incomingData)

            while let range = self.dataBuffer.firstRange(of: "\n".data(using: .utf8)!) {
                let lineData = self.dataBuffer.subdata(in: 0..<range.lowerBound)
                self.dataBuffer.removeSubrange(0..<range.upperBound)
                if !lineData.isEmpty {
                    self.processLine(lineData)
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.listeningProcess = nil
                AppLog.info("[MediaRemoteAdapter] Subprocess terminated")
            }
        }

        listeningProcess = process

        do {
            try process.run()
        } catch {
            AppLog.error("[MediaRemoteAdapter] Failed to start subprocess: \(error)")
            listeningProcess = nil
        }
    }

    func stopListening() {
        listeningProcess?.terminate()
        listeningProcess = nil
    }

    // MARK: - One-shot commands

    private func runCommand(_ command: String) {
        guard let scriptPath = perlScriptPath,
              let libraryPath = libraryPath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, libraryPath, command]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLog.error("[MediaRemoteAdapter] Command '\(command)' failed: \(error)")
        }
    }

    func play() { runCommand("play") }
    func pause() { runCommand("pause") }
    func togglePlayPause() { runCommand("toggle_play_pause") }
    func nextTrack() { runCommand("next_track") }
    func previousTrack() { runCommand("previous_track") }
    func stop() { runCommand("stop") }

    func updatePlayerState() {
        guard let scriptPath = perlScriptPath,
              let libraryPath = libraryPath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, libraryPath, "update_player_state"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            if let output = String(data: outputData, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) {
                    if !line.isEmpty, let lineData = line.data(using: .utf8) {
                        processLine(lineData)
                    }
                }
            }
        } catch {
            AppLog.error("[MediaRemoteAdapter] updatePlayerState failed: \(error)")
        }
    }

    func setTime(seconds: Double) {
        guard let scriptPath = perlScriptPath,
              let libraryPath = libraryPath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, libraryPath, "set_time", String(seconds)]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            AppLog.error("[MediaRemoteAdapter] setTime failed: \(error)")
        }
    }

    // MARK: - JSON line processing

    private func processLine(_ lineData: Data) {
        do {
            guard let rawInfo = try JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { return }
            let notificationName = rawInfo["notificationName"] as? String ?? ""

            if notificationName == "kMRMediaRemoteNowPlayingInfoDidChangeNotification" {
                let payload = rawInfo["payload"] as? [String: Any]
                DispatchQueue.main.async {
                    self.onTrackInfoReceived?(payload ?? [:])
                }
            } else if notificationName == "kMRMediaRemoteNowPlayingApplicationPlaybackStateDidChangeNotification" {
                let payload = rawInfo["payload"] as? [String: Any]
                if let playbackState = payload?["playbackState"] as? Int {
                    DispatchQueue.main.async {
                        self.onPlaybackStateReceived?(playbackState)
                    }
                }
            }
        } catch {
            AppLog.error("[MediaRemoteAdapter] JSON parse error: \(error)")
        }
    }

    deinit {
        stopListening()
    }
}
