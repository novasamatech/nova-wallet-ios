import Foundation

final class WalletConnectTransport {
    let service: WalletConnectServiceProtocol
    let dataSource: DAppStateDataSource

    private var state: WalletConnectStateProtocol?

    init(service: WalletConnectServiceProtocol, dataSource: DAppStateDataSource) {
        self.service = service
        self.dataSource = dataSource
    }
}

extension WalletConnectTransport: DAppTransportProtocol {
    var name: String { DAppTransports.walletConnect }

    func isIdle() -> Bool {
        state?.canHandleMessage() ?? false
    }

    func bringPhishingDetectedStateIfNeeded() -> Bool {

    }

    func process(message: Any, host: String) {
        guard let message = message as? WalletConnectStateMessage else {
            return
        }

        state?.handle(message: message, dataSource: dataSource)
    }

    func processConfirmation(response: DAppOperationResponse) {
        state?.handleOperation(response: response, dataSource: dataSource)
    }

    func processAuth(response: DAppAuthResponse) {
        state?.handleAuth(response: response, dataSource: dataSource)
    }

    func processChainsChanges() {

    }
}
