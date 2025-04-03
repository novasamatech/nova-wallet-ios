import Foundation

final class TransakOffRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func createEventListeningHook(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> RampHook {
        let eventName = TransakRampEventNames.walletRedirection.rawValue

        let scriptSource = """
            window.addEventListener("message", ({ data }) => {
                if (event.detail && event.detail.eventName === \(eventName)) {
                    window.webkit.messageHandlers.\(eventName).postMessage(JSON.stringify(data));
                }
            });
        """

        let handlers = [
            TransakOffRampResponseHandler(
                delegate: delegate,
                chainAsset: params.chainAsset,
                logger: logger
            )
        ]
        let hook = RampHook(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
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
