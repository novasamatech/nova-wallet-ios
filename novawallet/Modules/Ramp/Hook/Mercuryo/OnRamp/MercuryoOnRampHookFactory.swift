import Foundation

final class MercuryoOnRampHookFactory {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    private func createResponseInterceptingHook(for delegate: OnRampHookDelegate) -> RampHook {
        let onRampAction = MercuryoRampEventNames.onSell.rawValue

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            if (url.includes('\(MercuryoApi.buyEndpoint)')) {
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
