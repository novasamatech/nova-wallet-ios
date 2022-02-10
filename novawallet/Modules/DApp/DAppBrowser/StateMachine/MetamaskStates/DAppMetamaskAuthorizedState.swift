import Foundation

final class DAppMetamaskAuthorizedState: DAppMetamaskBaseState {
    private func provideEthereumAddresses(
        _ messageId: MetamaskMessage.Id,
        from dataSource: DAppBrowserStateDataSource
    ) throws {
        let addresses = dataSource.fetchEthereumAddresses()
        provideResponse(for: messageId, results: addresses, nextState: self)
    }

    private func addChain(from message: MetamaskMessage) throws {
        guard let chain = try message.object?.map(to: MetamaskChain.self) else {
            provideError(
                for: message.identifier,
                errorMessage: PolkadotExtensionError.unsupported.rawValue,
                nextState: self
            )

            return
        }

        let reloadCommand = createReloadCommand()

        stateMachine?.emit(
            chain: chain,
            postExecutionScript: PolkadotExtensionResponse(content: reloadCommand),
            nextState: self
        )
    }

    private func sendTransaction(from message: MetamaskMessage) {
        guard let transactionInfo = message.object else {
            provideError(
                for: message.identifier,
                errorMessage: PolkadotExtensionError.unsupported.rawValue,
                nextState: self
            )

            return
        }

        let requestId = message.identifier
        let nextState = DAppMetamaskSigningState(stateMachine: stateMachine, requestId: requestId)

        stateMachine?.emit(messageId: requestId, signingOperation: transactionInfo, nextState: nextState)
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
                try addChain(from: message)
            case .signTransaction:
                sendTransaction(from: message)
            }
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}
