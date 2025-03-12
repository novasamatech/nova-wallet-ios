import Foundation

extension MercuryoCardHookFactory {
    func createWidgetHook(for delegate: PayCardHookDelegate) -> PayCardHook {
        let statusAction = MercuryoMessageName.onCardStatusChange.rawValue

        let scriptSource = """
            window.addEventListener("message", ({ data }) => {
                window.webkit.messageHandlers.\(statusAction).postMessage(JSON.stringify(data));
            });
        """

        return .init(
            script: .init(
                content: scriptSource,
                insertionPoint: .atDocEnd
            ),
            messageNames: [statusAction],
            handlers: [MercuryoCardStatusHandler(delegate: delegate, logger: logger)]
        )
    }
}
