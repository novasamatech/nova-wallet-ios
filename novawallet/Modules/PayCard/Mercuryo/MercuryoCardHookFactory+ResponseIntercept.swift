import Foundation

extension MercuryoCardHookFactory {
    func createCardsResponseInterceptingHook(for delegate: PayCardHookDelegate) -> PayCardHook {
        let actionName = MercuryoMessageName.onCardsResponse.rawValue
        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            if (url === '\(MercuryoCardApi.cardsEndpoint)') {
                this.addEventListener('load', function() {
                    window.webkit.messageHandlers.\(actionName).postMessage(this.responseText);
                });
            }

            originalXhrOpen.apply(this, arguments);
        };
        """

        return .init(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
            messageNames: [actionName],
            handlers: [
                MercuryoCardsResponseHandler(delegate: delegate, logger: logger)
            ]
        )
    }
}
