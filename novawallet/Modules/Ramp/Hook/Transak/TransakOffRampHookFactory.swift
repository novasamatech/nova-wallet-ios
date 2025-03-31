import Foundation

final class TransakOffRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func createResponseInterceptingHook(
        using params: OffRampParams,
        for delegate: OffRampHookDelegate
    ) -> RampHook {
        let offRampAction = MercuryoMessageName.onCardTopup.rawValue

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            if (url.includes('\(MercuryoCardApi.topUpEndpoint)')) {
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

extension TransakOffRampHookFactory: OffRampHookFactoryProtocol {
    func createHooks(
        using params: OffRampParams,
        for delegate: OffRampHookDelegate
    ) -> [RampHook] {
        let responseHook = createResponseInterceptingHook(
            using: params,
            for: delegate
        )

        return [responseHook]
    }
}
