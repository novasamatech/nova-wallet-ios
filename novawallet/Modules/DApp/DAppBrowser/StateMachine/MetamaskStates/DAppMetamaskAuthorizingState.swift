import Foundation
import RobinHood

final class DAppMetamaskAuthorizingState: DAppMetamaskBaseState {
    let requestId: MetamaskMessage.Id
    let host: String

    init(stateMachine: DAppMetamaskStateMachineProtocol?, chain: MetamaskChain, requestId: MetamaskMessage.Id, host: String) {
        self.requestId = requestId
        self.host = host

        super.init(stateMachine: stateMachine, chain: chain)
    }

    func saveAuthAndComplete(
        _ approved: Bool,
        host: String,
        dataSource: DAppBrowserStateDataSource
    ) {
        let fetchOperations = dataSource.dAppSettingsRepository.fetchOperation(
            by: host,
            options: RepositoryFetchOptions()
        )

        let saveOperation = dataSource.dAppSettingsRepository.saveOperation({
            let currentSettings = try fetchOperations.extractNoCancellableResultData()

            let newSettings = DAppSettings(
                identifier: currentSettings?.identifier ?? host,
                allowed: approved,
                favorite: currentSettings?.favorite ?? false
            )

            return [newSettings]
        }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.complete(approved, dataSource: dataSource)
            }
        }

        saveOperation.addDependency(fetchOperations)

        dataSource.operationQueue.addOperations([fetchOperations, saveOperation], waitUntilFinished: false)
    }

    func complete(_ approved: Bool, dataSource: DAppBrowserStateDataSource) {
        if approved {
            let addresses = dataSource.fetchEthereumAddresses().compactMap { $0.toEthereumAddressWithChecksum() }

            let nextState = DAppMetamaskAuthorizedState(stateMachine: stateMachine, chain: chain)

            guard let selectedAddress = addresses.first else {
                provideResponse(for: requestId, results: [], nextState: nextState)
                return
            }

            let setSelectedAddressCommand = createSetAddressCommand(selectedAddress)
            let addressesCommand = createResponseCommand(for: requestId, results: addresses)

            let content = createContentWithCommands([setSelectedAddressCommand, addressesCommand])
            let response = DAppScriptResponse(content: content)

            stateMachine?.emitReload(with: response, nextState: nextState)

        } else {
            let nextState = DAppMetamaskDeniedState(stateMachine: stateMachine, chain: chain)

            let error = MetamaskError.rejected
            provideError(for: requestId, error: error, nextState: nextState)
        }
    }
}

extension DAppMetamaskAuthorizingState: DAppMetamaskStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {}

    func canHandleMessage() -> Bool { false }

    func fetchSelectedAddress(from _: DAppBrowserStateDataSource) -> AccountAddress? { nil }

    func handle(message: MetamaskMessage, host: String, dataSource _: DAppBrowserStateDataSource) {
        let message = "can't handle message from \(host) while authorizing"
        let error = DAppBrowserStateError.unexpected(reason: message)

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while waiting auth response"
        )

        stateMachine?.emit(error: error, nextState: self)
    }

    func handleAuth(response: DAppAuthResponse, dataSource: DAppBrowserStateDataSource) {
        saveAuthAndComplete(response.approved, host: host, dataSource: dataSource)
    }
}
