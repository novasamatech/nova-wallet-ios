import Foundation

final class DAppMetamaskAuthorizedState: DAppMetamaskBaseState {
    private func provideEthereumAddresses(
        _ messageId: MetamaskMessage.Id,
        from dataSource: DAppBrowserStateDataSource
    ) throws {
        let addresses = dataSource.fetchEthereumAddresses()
        provideResponse(for: messageId, results: addresses, nextState: self)
    }

    private func switchChain(from message: MetamaskMessage) throws {
        guard let request = try message.object?.map(to: MetamaskSwitchChain.self) else {
            let error = MetamaskError.invalidParams(with: "can't parse chain")
            provideError(for: message.identifier, error: error, nextState: self)
            return
        }

        guard request.chainId != stateMachine?.chain?.chainId else {
            provideNullResponse(to: message.identifier, nextState: self)
            return
        }

        let ethereumChain = MetamaskChain.etheremChain

        if request.chainId == ethereumChain.chainId {
            let chainIdCommand = createSetChainIdCommand(ethereumChain.chainId)
            let nullResponseCommand = createNullResponseCommand(for: message.identifier)
            let reloadCommand = createReloadCommand()
            let content = createContentWithCommands([chainIdCommand, nullResponseCommand, reloadCommand])

            stateMachine?.emit(
                chain: ethereumChain,
                postExecutionScript: DAppScriptResponse(content: content),
                nextState: self
            )
        } else {
            let error = MetamaskError.noChainSwitch
            provideError(for: message.identifier, error: error, nextState: self)
        }
    }

    private func addChain(from message: MetamaskMessage) throws {
        guard let chain = try message.object?.map(to: MetamaskChain.self) else {
            let error = MetamaskError.invalidParams(with: "can't parse chain")
            provideError(for: message.identifier, error: error, nextState: self)
            return
        }

        if chain.chainId != stateMachine?.chain?.chainId {
            let reloadCommand = createReloadCommand()

            stateMachine?.emit(
                chain: chain,
                postExecutionScript: DAppScriptResponse(content: reloadCommand),
                nextState: self
            )
        } else {
            provideNullResponse(to: message.identifier, nextState: self)
        }
    }

    private func sendTransaction(from message: MetamaskMessage) {
        guard let transactionInfo = message.object else {
            let error = MetamaskError.invalidParams(with: "transaction missing")
            provideError(for: message.identifier, error: error, nextState: self)

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

    func handle(message: MetamaskMessage, host _: String, dataSource: DAppBrowserStateDataSource) {
        do {
            switch message.name {
            case .requestAccounts:
                try provideEthereumAddresses(message.identifier, from: dataSource)
            case .addEthereumChain:
                try addChain(from: message)
            case .switchEthereumChain:
                try switchChain(from: message)
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
