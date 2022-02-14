import Foundation

final class DAppBrowserAccountSubscribingState: DAppBrowserBaseState {
    let requestId: String

    init(stateMachine: DAppBrowserStateMachineProtocol?, requestId: String) {
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }
}

extension DAppBrowserAccountSubscribingState: DAppBrowserStateProtocol {
    func setup(with dataSource: DAppBrowserStateDataSource) {
        do {
            guard let accounts = try? dataSource.fetchAccountList() else {
                throw DAppBrowserStateError.unexpected(reason: "can't fetch account list")
            }

            let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)
            try provideSubscription(for: requestId, result: accounts, nextState: nextState)
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func canHandleMessage() -> Bool { false }

    func handle(message _: PolkadotExtensionMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message while subscribing")

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while subscribing"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response while subscribing"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}
