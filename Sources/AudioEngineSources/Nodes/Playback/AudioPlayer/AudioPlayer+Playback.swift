// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation

public extension AudioPlayer {
    // MARK: - Playback

    /// Play now or at a future time
    /// - Parameters:
    ///   - when: What time to schedule for. A value of nil means now or will
    ///   use a pre-existing scheduled time.
    ///   - completionCallbackType: Constants that specify when the completion handler must be invoked.
    func play(from startTime: TimeInterval? = nil,
              to endTime: TimeInterval? = nil,
              at when: AVAudioTime? = nil,
              completionCallbackType: AVAudioPlayerNodeCompletionCallbackType = .dataPlayedBack)
    {
        guard let engine = playerNode.engine else {
            Log("🛑 Error: AudioPlayer must be attached before playback.", type: .error)
            return
        }

        guard engine.isRunning else {
            Log("🛑 Error: AudioPlayer's engine must be running before playback.", type: .error)
            return
        }

        guard status != .playing else { return }

        editStartTime = startTime ?? editStartTime
        editEndTime = endTime ?? editEndTime

        if let nodeTime = playerNode.lastRenderTime, let whenTime = when {
            timeBeforePlay = whenTime.timeIntervalSince(otherTime: nodeTime) ?? 0
        } else if let playerTime = playerTime {
            timeBeforePlay = playerTime
        }

        if status == .paused {
            resume()
        } else {
            schedule(at: when, completionCallbackType: completionCallbackType)
            playerNode.play()
            status = .playing
        }
    }

    /// Pauses audio player. Calling play() will resume playback.
    func pause() {
        guard status == .playing else { return }
        pausedTime = currentTime
        playerNode.pause()
        status = .paused
    }

    /// Resumes playback immediately if the player is paused.
    func resume() {
        guard status == .paused else { return }
        playerNode.play()
        status = .playing
    }

    /// Stop audio player. This won't generate a callback event
    func stop() {
        guard status != .stopped else { return }
        status = .stopped
        playerNode.stop()
        timeBeforePlay = 0
    }

    /// Seeks through the player's audio file by the given time (in seconds).
    /// Positive time seeks forwards, negative time seeks backwards.
    /// - Parameters:
    ///   - time seconds, relative to current playback, to seek by
    func seek(time seekTime: TimeInterval) {
        let newTime = currentTime + seekTime
        seekInternal(to: newTime)
    }

    func seek(to absoluteTime: TimeInterval) {
        seekInternal(to: absoluteTime)
    }

    private func seekInternal(to targetTime: TimeInterval) {
        guard let file = file else { return }

        let sampleRate = file.fileFormat.sampleRate
        let clampedTime = min(editEndTime, max(0, targetTime))

        let startFrame = AVAudioFramePosition(clampedTime * sampleRate)
        let endFrame = AVAudioFramePosition(editEndTime * sampleRate)
        let frameCount = AVAudioFrameCount(max(1, endFrame - startFrame))

        playerNode.stop()
        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        )

        if isPlaying {
            playerNode.play()
            status = .playing
        } else {
            status = .paused
            pausedTime = clampedTime
        }
        timeBeforePlay = editStartTime - clampedTime
    }

    /// The current playback position, in range [0, 1].
    /// The start and end positions are 0 and 1, respectively.
    var currentPosition: Double {
        let duration = editEndTime - editStartTime
        return (currentTime / duration).clamped(to: 0...1)
    }

    /// The current playback time, in seconds.
    var currentTime: TimeInterval {
        guard status != .paused else { return pausedTime }
        guard status != .stopped else { return editStartTime }

        let startTime = editStartTime
        let duration = editEndTime - startTime

        guard let playerTime = isBuffered && isLooping
                ? playerTime?.truncatingRemainder(dividingBy: duration)
                : playerTime
        else { return startTime }

        let timeBeforePlay = playerTime >= timeBeforePlay ? timeBeforePlay : 0
        let time = startTime + playerTime - timeBeforePlay

        return time.clamped(to: startTime...startTime + duration)
    }

    /// The time the node has been playing,  in seconds. This is `nil`
    /// when the node is paused or stopped. The node's "playerTime" is not
    /// stopped when the file completes playback.
    var playerTime: TimeInterval? {
        guard let nodeTime = playerNode.lastRenderTime, nodeTime.isSampleTimeValid else { return nil }
        guard let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return nil }

        let sampleTime = Double(playerTime.sampleTime)
        let sampleRate = playerTime.sampleRate

        return sampleTime / sampleRate
    }
}

public extension AudioPlayer {
    /// Synonym for isPlaying
    var isStarted: Bool { isPlaying }

    /// Synonym for play()
    func start() {
        play()
    }
}
