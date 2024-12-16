import Foundation

extension MercuryoCardHookFactory {
    func createWidgetHooks(for delegate: PayCardHookDelegate) -> [PayCardHook] {
        let statusAction = MercuryoMessageName.onCardStatusChange.rawValue

        let scriptSource = """
        {
            data => {
                window.webkit.messageHandlers.\(statusAction).postMessage(JSON.stringify(data))
            }
        };
        """

        return [
            .init(
                script: .init(
                    content: scriptSource,
                    insertionPoint: .atDocEnd
                ),
                messageNames: [statusAction],
                handlers: [MercuryoCardStatusHandler(delegate: delegate, logger: logger)]
            )
        ]
    }
}
