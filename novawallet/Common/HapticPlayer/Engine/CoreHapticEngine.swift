import Foundation
import Foundation_iOS
import CoreHaptics

final class CoreHapticEngine {
    private let logger: LoggerProtocol
    private let applicationHandler: ApplicationHandlerProtocol

    private var engine: CHHapticEngine?
    private var needsStartup: Bool = true

    init(
        logger: LoggerProtocol,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.logger = logger
        self.applicationHandler = applicationHandler

        setup()
    }
}

// MARK: Private

private extension CoreHapticEngine {
    func setup() {
        applicationHandler.delegate = self
        setupEngine()
    }

    func setupEngine() {
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            needsStartup = false

            engine?.stoppedHandler = { [weak self] reason in
                self?.needsStartup = true
                self?.logger.info("Haptic engine stopped for reason: \(reason.rawValue)")
            }

            engine?.resetHandler = { [weak self] in
                self?.logger.info("Haptic engine reset")

                guard self?.needsStartup == true else { return }

                do {
                    try self?.engine?.start()
                    self?.needsStartup = false
                } catch {
                    self?.logger.error("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            logger.error("Error creating haptic engine: \(error)")
        }
    }

    func createEvent(
        intensity: Float,
        sharpness: Float,
        eventType: CHHapticEvent.EventType,
        relativeTime: TimeInterval,
        duration: TimeInterval? = nil
    ) -> CHHapticEvent {
        let intensityParameter = CHHapticEventParameter(
            parameterID: .hapticIntensity,
            value: intensity
        )
        let sharpnessParameter = CHHapticEventParameter(
            parameterID: .hapticSharpness,
            value: sharpness
        )

        return if let duration {
            CHHapticEvent(
                eventType: eventType,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: relativeTime,
                duration: duration
            )
        } else {
            CHHapticEvent(
                eventType: eventType,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: relativeTime
            )
        }
    }

    func playEvents(_ events: [CHHapticEvent]) {
        guard let engine else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)

            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Error playing haptic: \(error)")
        }
    }
}

// MARK: HapticEngine

extension CoreHapticEngine: HapticEngine {
    func generateTransientHaptic(
        intensity: Float,
        sharpness: Float
    ) {
        let event = createEvent(
            intensity: intensity,
            sharpness: sharpness,
            eventType: .hapticTransient,
            relativeTime: 0
        )

        playEvents([event])
    }

    func generateContinuousHaptic(
        intensity: Float,
        sharpness: Float,
        duration: TimeInterval
    ) {
        let event = createEvent(
            intensity: intensity,
            sharpness: sharpness,
            eventType: .hapticContinuous,
            relativeTime: 0,
            duration: duration
        )

        playEvents([event])
    }

    func generateHapticSequence(
        intensities: [Float],
        sharpness: [Float],
        spacing: TimeInterval
    ) {
        let events: [CHHapticEvent] = intensities
            .enumerated()
            .map { index, intensity in
                let relativeTime = TimeInterval(index) * spacing

                let eventSharpness: Float = if index < sharpness.count {
                    sharpness[index]
                } else {
                    0.0
                }

                return createEvent(
                    intensity: intensity,
                    sharpness: eventSharpness,
                    eventType: .hapticTransient,
                    relativeTime: relativeTime
                )
            }

        playEvents(events)
    }
}

// MARK: ApplicationHandlerDelegate

extension CoreHapticEngine: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        engine?.stop { [weak self] error in
            if let error = error {
                self?.logger.error("Haptic Engine Shutdown Error: \(error)")
                return
            }

            self?.needsStartup = true
        }
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        engine?.start { [weak self] error in
            if let error = error {
                self?.logger.error("Haptic Engine Startup Error: \(error)")
                return
            }

            self?.needsStartup = false
        }
    }
}
