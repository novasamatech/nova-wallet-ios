import Foundation

final class TransakOnRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createEventListeningHook(for delegate: OnRampHookDelegate) -> RampHook {
        let eventName = TransakRampEventNames.webViewEventsName.rawValue

        let handlers = [
            TransakOnRampResponseHandler(
                delegate: delegate,
                logger: logger
            )
        ]
        let hook = RampHook(
            script: nil,
            messageNames: [eventName],
            handlers: handlers
        )

        return hook
    }
}

extension TransakOnRampHookFactory: OnRampHookFactoryProtocol {
    func createHooks(for delegate: OnRampHookDelegate) -> [RampHook] {
        let hook = createEventListeningHook(for: delegate)

        return [hook]
    }
}
