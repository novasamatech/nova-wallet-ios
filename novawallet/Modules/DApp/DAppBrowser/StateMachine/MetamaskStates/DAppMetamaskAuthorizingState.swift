import Foundation

final class DAppMetamaskAuthorizingState: DAppMetamaskBaseState {
    let requestId: MetamaskMessage.Id

    init(stateMachine: DAppMetamaskStateMachineProtocol?, requestId: MetamaskMessage.Id) {
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }

    func complete(_ approved: Bool, dataSource: DAppBrowserStateDataSource) {
        if approved {
            let addresses = dataSource.fetchEthereumAddresses()

            let nextState = DAppMetamaskAuthorizedState(stateMachine: stateMachine)

            provideResponse(for: requestId, results: addresses, nextState: nextState)

        } else {
            let nextState = DAppMetamaskDeniedState(stateMachine: stateMachine)

            provideError(
                for: requestId,
                errorMessage: PolkadotExtensionError.rejected.rawValue,
                nextState: nextState
            )
        }
    }
}

extension DAppMetamaskAuthorizingState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func handle(message _: MetamaskMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message while authorizing")

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while waiting auth response"
        )

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource) {
        complete(response.approved, dataSource: dataSource)
    }
}
