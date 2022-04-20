import Foundation
import SubstrateSdk

final class DAppMetamaskAuthorizedState: DAppMetamaskBaseState {
    private func provideEthereumAddresses(
        _ messageId: MetamaskMessage.Id,
        from dataSource: DAppBrowserStateDataSource
    ) throws {
        let addresses = dataSource.fetchEthereumAddresses(for: chain.chainId).compactMap {
            $0.toEthereumAddressWithChecksum()
        }

        provideResponse(for: messageId, results: addresses, nextState: self)
    }

    private func sendTransaction(from message: MetamaskMessage) {
        guard let transactionInfo = message.object else {
            let error = MetamaskError.invalidParams(with: "transaction missing")
            provideError(for: message.identifier, error: error, nextState: self)

            return
        }

        let requestId = message.identifier
        let nextState = DAppMetamaskSigningState(
            stateMachine: stateMachine,
            chain: chain,
            requestId: requestId
        )

        stateMachine?.emit(messageId: requestId, signingOperation: transactionInfo, nextState: nextState)
    }

    private func signPersonalMessage(from message: MetamaskMessage) {
        guard
            let hexString = message.object?.data?.stringValue,
            let signingHashedData = try? Data(
                hexString: hexString
            ).ethereumPersonalSignMessage()?.keccak256() else {
            let error = MetamaskError.invalidParams(with: "can't create signing data")
            provideError(for: message.identifier, error: error, nextState: self)

            return
        }

        emitSigningBytesOperation(for: message, hashedData: signingHashedData)
    }

    private func signTypedData(from message: MetamaskMessage) {
        guard
            let hexString = message.object?.data?.stringValue,
            let signingHashedData = try? Data(hexString: hexString) else {
            let error = MetamaskError.invalidParams(with: "can't create signing data")
            provideError(for: message.identifier, error: error, nextState: self)

            return
        }

        emitSigningBytesOperation(for: message, hashedData: signingHashedData)
    }

    private func emitSigningBytesOperation(for message: MetamaskMessage, hashedData: Data) {
        let requestId = message.identifier
        let nextState = DAppMetamaskSigningState(
            stateMachine: stateMachine,
            chain: chain,
            requestId: requestId
        )

        let signingJson = JSON.stringValue(hashedData.toHex(includePrefix: true))

        stateMachine?.emit(messageId: requestId, signingOperation: signingJson, nextState: nextState)
    }
}

extension DAppMetamaskAuthorizedState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool {
        true
    }

    func fetchSelectedAddress(from dataSource: DAppBrowserStateDataSource) -> AccountAddress? {
        dataSource.fetchEthereumAddresses(for: chain.chainId).first?.toEthereumAddressWithChecksum()
    }

    func handle(message: MetamaskMessage, host _: String, dataSource: DAppBrowserStateDataSource) {
        do {
            switch message.name {
            case .requestAccounts:
                try provideEthereumAddresses(message.identifier, from: dataSource)
            case .addEthereumChain:
                addChain(
                    from: message,
                    dataSource: dataSource,
                    nextStateSuccessClosure: { newChain in
                        DAppMetamaskAuthorizedState(stateMachine: stateMachine, chain: newChain)
                    }, nextStateFailureClosure: { _ in
                        DAppMetamaskAuthorizedState(stateMachine: stateMachine, chain: chain)
                    }
                )
            case .switchEthereumChain:
                switchChain(
                    from: message,
                    dataSource: dataSource,
                    nextStateSuccessClosure: { newChain in
                        DAppMetamaskAuthorizedState(stateMachine: stateMachine, chain: newChain)
                    }, nextStateFailureClosure: { _ in
                        DAppMetamaskAuthorizedState(stateMachine: stateMachine, chain: chain)
                    }
                )
            case .signTransaction:
                sendTransaction(from: message)
            case .signPersonalMessage:
                signPersonalMessage(from: message)
            case .signTypedMessage:
                signTypedData(from: message)
            }
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}
