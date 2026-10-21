import Foundation

final class MercuryoOnRampHookFactory {
    #if F_RELEASE
        private static let buyEndpoints = [MercuryoApi.buyEndpoint]
    #else
        private static let buyEndpoints = [
            MercuryoApi.buyEndpoint,
            "https://sandbox-api.mrcr.io/v1.6/widget/buy"
        ]
    #endif

    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createResponseInterceptingHook(for delegate: OnRampHookDelegate) -> RampHook {
        let onRampAction = MercuryoRampEventNames.onBuy.rawValue
        let buyEndpoints = Self.buyEndpoints.map { "'\($0)/'" }.joined(with: .commaSpace)

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            var isBuyRequest = [\(buyEndpoints)].some(function(endpoint) {
                return url.includes(endpoint);
            });

            if (isBuyRequest && url.split('?')[0].endsWith('/status')) {
                this.addEventListener('load', function() {
                    window.webkit.messageHandlers.\(onRampAction).postMessage(this.responseText);
                });
            }

            originalXhrOpen.apply(this, arguments);
        };
        """

        let handlers: [PayCardMessageHandling] = [
            MercuryoOnRampResponseHandler(
                delegate: delegate,
                logger: logger
            )
        ]

        return .init(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
            messageNames: [onRampAction],
            handlers: handlers
        )
    }
}

extension MercuryoOnRampHookFactory: OnRampHookFactoryProtocol {
    func createHooks(for delegate: OnRampHookDelegate) -> [RampHook] {
        let responseHook = createResponseInterceptingHook(for: delegate)

        return [responseHook]
    }
}
