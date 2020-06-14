import CoreHaptics

// MARK:- Haptics

public class Haptics {
    
    var state: State = .stopped(.neverStarted)
    var supportsAudio: Bool
    var supportsHaptics: Bool
    
    private(set) var engineResetCount = 0
    var engineResetMaxAttempts = 5
    
    public init() {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        supportsAudio = capabilities.supportsAudio
        supportsHaptics = capabilities.supportsHaptics
        
        guard supportsHaptics else {
            self.state = .stopped(.notSupported)
            return
        }
        
        setupEngine()
    }
}


// MARK:- State

extension Haptics {
    
    public enum State {
        case started(CHHapticEngine)
        case stopped(Reason)
        
        public enum Reason {
            case neverStarted
            case notSupported
            case engineStopped(CHHapticEngine.StoppedReason)
            case error(Error)
        }
    }
    
    var engine: CHHapticEngine? {
        if case let .started(o) = state { return o } else { return nil }
    }
}


// MARK:- Setup

extension Haptics {
    
    func setupEngine() {
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            engine.stoppedHandler = { [weak self] reason in
                Haptics.log("Engine stopped: \(reason)")
                self?.state = .stopped(.engineStopped(reason))
            }
            engine.resetHandler = { [weak self] in
                Haptics.log("Engine resetting")
                guard let self = self, self.engineResetCount < self.engineResetMaxAttempts else { return }
                self.setupEngine()
                self.engineResetCount += 1
            }
            engineResetCount = 0
            state = .started(engine)
        } catch {
            log("Unable to setup engine: \(error)")
            state = .stopped(.error(error))
        }
    }
}


// MARK:- Playback

extension Haptics {
    
    public func play(_ pattern: CHHapticPattern, atTime time: TimeInterval = CHHapticTimeImmediate) {
        guard let player = player(for: pattern) else { return }
        do { try player.start(atTime: time) }
        catch { log("Unable to create play pattern: \(error)") }
    }
    
    public func play(_ patternData: Data) {
        guard let engine = engine else { return }
        do { try engine.playPattern(from: patternData) }
        catch { log("Unable to play pattern: \(error)") }
    }
    
    public func play(_ patternURL: URL) {
        guard let engine = engine else { return }
        do { try engine.playPattern(from: patternURL) }
        catch { log("Unable to play pattern: \(error)") }
    }
    
    public func player(for pattern: CHHapticPattern) -> CHHapticAdvancedPatternPlayer? {
        guard let engine = engine else { return nil }
        do {
            return try engine.makeAdvancedPlayer(with: pattern)
        } catch {
            log("Unable to create Pattern Player: \(error)")
            return nil
        }
    }
}

extension Haptics {
    
    public func play(audioURL url: URL) throws {
        guard let engine = engine else { return }
        
        let id: CHHapticAudioResourceID
        do { id = try engine.registerAudioResource(url, options: [:]) }
        catch { log("Unable to register audio resource: \(error)"); throw error }
        
        let pattern = try! CHHapticPattern(
            events: [
                CHHapticEvent(audioResourceID: id, parameters: [], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ], relativeTime: 0, duration: 0.6)
            ],
            parameters: [
                CHHapticDynamicParameter(parameterID: .hapticReleaseTimeControl, value: 0.7, relativeTime: 0)
            ]
        )
        
        play(pattern)
    }
}

// MARK:- Utilities

extension Haptics {
    
    static var logging = true
    
    enum LogLevel: String { case warning, error }
    
    func log(_ message: String, _ level: LogLevel = .warning) {
        Haptics.log(message, level)
    }
    
    static func log(_ message: String, _ level: LogLevel = .warning) {
        guard Haptics.logging else { return }
        print("📳 Haptics \(level)\t", message)
    }
}

extension CHHapticEngine.StoppedReason: CustomStringConvertible {
    
    public var description: String {
        switch self {
        
        case .audioSessionInterrupt: return "Audio Session Interrupt"
        case .applicationSuspended: return "Application Suspended"
        case .idleTimeout: return "Idle Timeout"
        case .notifyWhenFinished: return "Notify When Finished"
        case .systemError: return "System Error"
        @unknown default: return "Unknown"
        }
    }
}
