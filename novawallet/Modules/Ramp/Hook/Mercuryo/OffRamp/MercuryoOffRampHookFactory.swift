import Foundation

final class MercuryoOffRampHookFactory {
    #if F_RELEASE
        private static let sellRequestEndpoints = [MercuryoApi.topUpEndpoint]
    #else
        private static let sellRequestEndpoints = [
            MercuryoApi.topUpEndpoint,
            "https://sandbox-api.mrcr.io/v1.6/widget/sell-request"
        ]
    #endif

    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createResponseInterceptingHook(
        using params: OffRampHookParams,
        for delegate: OffRampHookDelegate
    ) -> RampHook {
        let offRampAction = MercuryoRampEventNames.onSell.rawValue
        let sellRequestEndpoints = Self.sellRequestEndpoints.map { "'\($0)'" }.joined(with: .commaSpace)

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            var isSellRequest = [\(sellRequestEndpoints)].some(function(endpoint) {
                return url.includes(endpoint);
            });

            if (isSellRequest) {
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
