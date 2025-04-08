import Foundation

final class TransakOffRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createEventListeningHook(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> RampHook {
        let eventName = TransakRampEventNames.webViewEventsName.rawValue

        let handlers = [
            TransakOffRampResponseHandler(
                delegate: delegate,
                chainAsset: params.chainAsset,
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

extension TransakOffRampHookFactory: OffRampHookFactoryProtocol {
    func createHooks(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> [RampHook] {
        let hook = createEventListeningHook(
            using: params,
            for: delegate
        )

        return [hook]
    }
}
