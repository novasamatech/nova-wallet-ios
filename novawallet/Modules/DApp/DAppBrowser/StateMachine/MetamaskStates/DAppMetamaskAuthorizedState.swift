import Foundation

final class DAppMetamaskAuthorizedState: DAppMetamaskBaseState {
    private func provideEthereumAddresses(
        _ messageId: MetamaskMessage.Id,
        from dataSource: DAppBrowserStateDataSource
    ) throws {
        let addresses = dataSource.fetchEthereumAddresses()
        provideResponse(for: messageId, results: addresses, nextState: self)
    }

    private func addChain(
        _ chain: MetamaskChain,
        messageId _: MetamaskMessage.Id,
        dataSource _: DAppBrowserStateDataSource
    ) {
        let reloadCommand = createReloadCommand()

        stateMachine?.emit(
            chain: chain,
            postExecutionScript: PolkadotExtensionResponse(content: reloadCommand),
            nextState: self
        )
    }
}

extension DAppMetamaskAuthorizedState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool {
        true
    }

    func handle(message: MetamaskMessage, dataSource: DAppBrowserStateDataSource) {
        do {
            switch message.name {
            case .requestAccounts:
                try provideEthereumAddresses(message.identifier, from: dataSource)
            case .addEthereumChain:
                guard let chain = try message.object?.map(to: MetamaskChain.self) else {
                    provideError(
                        for: message.identifier,
                        errorMessage: PolkadotExtensionError.unsupported.rawValue,
                        nextState: self
                    )

                    return
                }

                addChain(chain, messageId: message.identifier, dataSource: dataSource)
            case .signTransaction:
                break
            case .requestChainId:
                break
            }
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}
