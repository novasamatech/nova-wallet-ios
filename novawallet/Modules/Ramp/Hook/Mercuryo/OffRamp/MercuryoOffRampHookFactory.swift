import Foundation

final class MercuryoOffRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createResponseInterceptingHook(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> RampHook {
        let offRampAction = MercuryoRampEventNames.onSell.rawValue

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            if (url.includes('\(MercuryoApi.topUpEndpoint)')) {
                this.addEventListener('load', function() {
                    window.webkit.messageHandlers.\(offRampAction).postMessage(this.responseText);
                });
            }

            originalXhrOpen.apply(this, arguments);
        };
        """

        let handlers: [PayCardMessageHandling] = [
            MercuryoOffRampResponseHandler(
                delegate: delegate,
                chainAsset: params.chainAsset,
                logger: logger
            )
        ]

        return .init(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
            messageNames: [offRampAction],
            handlers: handlers
        )
    }
}

extension MercuryoOffRampHookFactory: OffRampHookFactoryProtocol {
    func createHooks(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> [RampHook] {
        let responseHook = createResponseInterceptingHook(
            using: params,
            for: delegate
        )

        return [responseHook]
    }
}
