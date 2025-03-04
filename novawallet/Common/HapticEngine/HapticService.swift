import CoreHaptics
import SoraFoundation

class HapticService {
    private let config: PatternConfig
    private let logger: LoggerProtocol
    private let applicationHandler: ApplicationHandlerProtocol

    private var engine: CHHapticEngine?
    private var valueCounter = 0
    private var needsStartup: Bool = true

    init(
        config: PatternConfig,
        applicationHandler: ApplicationHandlerProtocol = ApplicationHandler(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.config = config
        self.applicationHandler = applicationHandler
        self.logger = logger

        setup()
    }
}

// MARK: Private

private extension HapticService {
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

extension HapticService: HapticEngine {
    func reset() {
        valueCounter = 0
    }

    func playConfiguredTransientHaptic(
        using triggerPositions: [Int],
        customIntensity: Float?,
        customSharpness: Float?
    ) {
        let currentPosition = (valueCounter % config.groupSize) == 0
            ? config.groupSize
            : (valueCounter % config.groupSize)

        guard triggerPositions.contains(currentPosition) else { return }

        let intensityFactor: Float = config.progressiveIntensity
            ? Float(triggerPositions.firstIndex(of: currentPosition) ?? 0 + 1) / Float(triggerPositions.count)
            : 1.0

        let finalIntensity = customIntensity ?? (config.baseIntensity * intensityFactor)
        let finalSharpness = customSharpness ?? config.baseSharpness

        playTransientHaptic(
            with: finalIntensity,
            sharpness: finalSharpness
        )
    }

    func playConfiguredTransientHaptic(
        with intensity: Float?,
        sharpness: Float?
    ) {
        let position = valueCounter % config.groupSize
        let triggerStartPosition = config.groupSize - config.triggerCount + 1

        guard position >= triggerStartPosition || position == 0 else { return }

        let triggerPosition = if position == 0 {
            config.triggerCount
        } else {
            position - triggerStartPosition + 1
        }

        let intensityFactor: Float = config.progressiveIntensity
            ? Float(triggerPosition) / Float(config.triggerCount)
            : 1.0

        let finalIntensity = intensity ?? (config.baseIntensity * intensityFactor)
        let finalSharpness = sharpness ?? config.baseSharpness

        playTransientHaptic(
            with: finalIntensity,
            sharpness: finalSharpness
        )
    }

    func playTransientHaptic(
        with intensity: Float,
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

    func triggerHapticFeedback(
        customIntensity: Float?,
        customSharpness: Float?
    ) {
        valueCounter += 1

        if let triggerPositions = config.triggerPositions {
            playConfiguredTransientHaptic(
                using: triggerPositions,
                customIntensity: customIntensity,
                customSharpness: customSharpness
            )
        } else {
            playConfiguredTransientHaptic(
                with: customIntensity,
                sharpness: customSharpness
            )
        }

        if valueCounter >= 1000 {
            valueCounter = valueCounter % config.groupSize
        }
    }

    func playTransientHaptic(
        intensity: Float,
        sharpness: Float
    ) {
        playTransientHaptic(
            with: intensity,
            sharpness: sharpness
        )
    }

    func playContinuousHaptic(
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

    func playHapticSequence(
        intensities: [Float],
        sharpness: [Float]?,
        spacing: TimeInterval
    ) {
        let events: [CHHapticEvent] = intensities
            .enumerated()
            .map { index, intensity in
                let relativeTime = TimeInterval(index) * spacing

                let eventSharpness = if let sharpness, index < sharpness.count {
                    sharpness[index]
                } else {
                    config.baseSharpness
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

extension HapticService: ApplicationHandlerDelegate {
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
