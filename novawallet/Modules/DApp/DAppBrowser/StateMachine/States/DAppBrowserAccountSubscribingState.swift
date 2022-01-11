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
            let accounts = try dataSource.fetchAccountList()

            let nextState = DAppBrowserAuthorizedState(stateMachine: stateMachine)
            try provideSubscription(for: requestId, result: accounts, nextState: nextState)
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func canHandleMessage() -> Bool { false }

    func handle(message _: PolkadotExtensionMessage, dataSource _: DAppBrowserStateDataSource) {}

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}
