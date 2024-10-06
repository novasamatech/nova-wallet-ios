import Foundation

extension MercuryoCardHookFactory {
    func createWidgetHooks(
        for _: PayCardHookDelegate,
        params: MercuryoCardParams
    ) throws -> [PayCardHook] {
        let refundAddress = try params.refundAccountId.toAddress(
            using: params.chainAsset.chain.chainFormat
        )

        let statusAction = MercuryoMessageName.onCardStatusChange.rawValue
        let topupAction = MercuryoMessageName.onCardTopup.rawValue

        let scriptSource = """
        mercuryoWidget.run({
            widgetId: '\(MercuryoCardApi.widgetId)',
            host: document.getElementById('widget-container'),
            type: 'sell',
            currency: '\(params.chainAsset.asset.symbol)',
            fiatCurrency: 'EUR',
            paymentMethod: 'fiat_card_open',
            theme: 'nova',
            showSpendCardDetails: true,
            width: '100%',
            fixPaymentMethod: true,
            height: window.innerHeight,
            hideRefundAddress: true,
            refundAddress: '\(refundAddress)',
            onStatusChange: data => {
                window.webkit.messageHandlers.\(statusAction).postMessage(JSON.stringify(data))
            },
            onSellTransferEnabled: data => {
                window.webkit.messageHandlers.\(topupAction).postMessage(JSON.stringify(data))
            }
        });
        """

        return [.init(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
            messageNames: [statusAction, topupAction],
            handlers: [
                MercuryoCardStatusHandler(logger: logger),
                MercuryoCardTopupHandler(logger: logger)
            ]
        )]
    }
}
