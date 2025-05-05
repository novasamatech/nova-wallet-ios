import Foundation

extension MercuryoCardHookFactory {
    func createResponseInterceptingHook(
        using params: MercuryoCardParams,
        for delegate: PayCardHookDelegate
    ) -> PayCardHook {
        let cardsAction = MercuryoMessageName.onCardsResponse.rawValue
        let topUpAction = MercuryoMessageName.onCardTopup.rawValue

        let scriptSource = """
        let originalXhrOpen = XMLHttpRequest.prototype.open;

        XMLHttpRequest.prototype.open = function(method, url) {
            if (url === '\(MercuryoApi.cardsEndpoint)') {
                this.addEventListener('load', function() {
                    window.webkit.messageHandlers.\(cardsAction).postMessage(this.responseText);
                });
            }

            if (url.includes('\(MercuryoApi.topUpEndpoint)')) {
                this.addEventListener('load', function() {
                    window.webkit.messageHandlers.\(topUpAction).postMessage(this.responseText);
                });
            }

            originalXhrOpen.apply(this, arguments);
        };
        """

        let handlers: [PayCardMessageHandling] = [
            MercuryoCardsResponseHandler(
                delegate: delegate,
                logger: logger
            ),
            MercuryoSellRequestResponseHandler(
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
            messageNames: [cardsAction, topUpAction],
            handlers: handlers
        )
    }
}
