import Foundation

final class DAppBrowserMetadataState: DAppBrowserBaseState {
    let previousState: DAppBrowserStateProtocol
    let metadata: PolkadotExtensionMetadata
    let requestId: String

    init(
        stateMachine: DAppBrowserStateMachineProtocol?,
        previousState: DAppBrowserStateProtocol,
        metadata: PolkadotExtensionMetadata,
        requestId: String
    ) {
        self.previousState = previousState
        self.metadata = metadata
        self.requestId = requestId

        super.init(stateMachine: stateMachine)
    }

    private func handle(
        coderFactory: RuntimeCoderFactoryProtocol,
        dataSource: DAppBrowserStateDataSource
    ) throws {
        if coderFactory.specVersion != metadata.specVersion {
            provideError(
                for: requestId,
                errorMessage: PolkadotExtensionError.unsupported.rawValue,
                nextState: previousState
            )
        } else {
            let genesisHash = metadata.genesisHash

            let metadata = PolkadotExtensionMetadata(
                genesisHash: genesisHash,
                specVersion: metadata.specVersion
            )

            dataSource.set(metadata: metadata, for: genesisHash)

            try provideResponse(for: requestId, result: true, nextState: previousState)
        }
    }

    private func handle(error: Error) {
        stateMachine?.emit(error: error, nextState: previousState)
    }
}

extension DAppBrowserMetadataState: DAppBrowserStateProtocol {
    func setup(with dataSource: DAppBrowserStateDataSource) {
        guard let genesisHashData = try? Data(hexString: metadata.genesisHash) else {
            provideError(
                for: requestId,
                errorMessage: "Invalid genesis hash",
                nextState: previousState
            )

            return
        }

        let chainId = genesisHashData.toHex()
        let chainRegistry = dataSource.chainRegistry
        let operationQueue = dataSource.operationQueue

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            provideError(
                for: requestId,
                errorMessage: PolkadotExtensionError.unsupported.rawValue,
                nextState: previousState
            )

            return
        }

        let operation = runtimeProvider.fetchCoderFactoryOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let coderFactory = try operation.extractNoCancellableResultData()
                    try self?.handle(coderFactory: coderFactory, dataSource: dataSource)
                } catch {
                    self?.handle(error: error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    func canHandleMessage() -> Bool { false }

    func handle(message _: PolkadotExtensionMessage, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(reason: "can't handle message while handling metadata")

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response while handling metadata"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response while handling metadata"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}
