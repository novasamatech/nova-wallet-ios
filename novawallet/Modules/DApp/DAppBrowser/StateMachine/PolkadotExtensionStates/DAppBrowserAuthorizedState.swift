import Foundation
import NovaCrypto

final class DAppBrowserAuthorizedState: DAppBrowserBaseState {
    private func provideAccountListResponse(
        from dataSource: DAppBrowserStateDataSource,
        requestId: String
    ) throws {
        guard let accounts = try? dataSource.fetchAccountList() else {
            throw DAppBrowserStateError.unexpected(reason: "can't fetch account list")
        }

        try provideResponse(for: requestId, result: accounts, nextState: self)
    }

    private func provideAccountSubscriptionResult(for requestId: String) throws {
        let nextState = DAppBrowserAccountSubscribingState(stateMachine: stateMachine, requestId: requestId)
        try provideResponse(for: requestId, result: true, nextState: nextState)
    }

    private func provideMetadataList(
        from dataSource: DAppBrowserStateDataSource,
        requestId: String
    ) throws {
        let metadataList = dataSource.metadataStore.map { _, value in
            PolkadotExtensionMetadataResponse(genesisHash: value.genesisHash, specVersion: value.specVersion)
        }

        try provideResponse(for: requestId, result: metadataList, nextState: self)
    }

    private func handleMetadata(from message: PolkadotExtensionMessage) {
        if let metadata = try? message.request?.map(to: PolkadotExtensionMetadata.self) {
            let nextState = DAppBrowserMetadataState(
                stateMachine: stateMachine,
                previousState: self,
                metadata: metadata,
                requestId: message.identifier
            )

            stateMachine?.emit(nextState: nextState)
        } else {
            let error = DAppBrowserStateError.unexpected(reason: "metadata message")
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    private func handleExtrinsicSigning(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        guard
            let jsonRequest = message.request,
            let extrinsic = try? jsonRequest.map(to: PolkadotExtensionExtrinsic.self) else {
            let error = DAppBrowserStateError.unexpected(reason: "extrinsic message")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        guard
            let chainId = try? Data(hexString: extrinsic.genesisHash).toHex(),
            let chain = dataSource.chainStore[chainId] else {
            let error = DAppBrowserStateError.unexpected(reason: "extrinsic chain")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        guard let accountId = dataSource.wallet.fetch(for: chain.accountRequest())?.accountId else {
            let error = DAppBrowserStateError.unexpected(reason: "no account for extrinsic chain")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            accountId: accountId,
            dApp: message.url ?? "",
            dAppIcon: dataSource.tab?.icon,
            operationData: jsonRequest
        )

        let type: DAppSigningType = .extrinsic(chain: chain)
        let nextState = DAppBrowserSigningState(
            stateMachine: stateMachine,
            signingType: type,
            requestId: message.identifier
        )
        stateMachine?.emit(signingRequest: request, type: type, nextState: nextState)
    }

    private func handleRawPayloadSigning(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        guard let payload = try? message.request?.map(to: PolkadotExtensionPayload.self) else {
            let error = DAppBrowserStateError.unexpected(reason: "raw payload message")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        guard let accountId = try? payload.address.toAccountId() else {
            let error = DAppBrowserStateError.unexpected(reason: "address format")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        guard let chain = try? dataSource.resolveSignBytesChain(for: payload.address) else {
            let error = DAppBrowserStateError.unexpected(reason: "raw payload chain")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            accountId: accountId,
            dApp: message.url ?? "",
            dAppIcon: dataSource.tab?.icon,
            operationData: .stringValue(payload.data)
        )

        let type: DAppSigningType = .bytes(chain: chain)
        let nextState = DAppBrowserSigningState(
            stateMachine: stateMachine,
            signingType: type,
            requestId: message.identifier
        )
        stateMachine?.emit(signingRequest: request, type: type, nextState: nextState)
    }
}

extension DAppBrowserAuthorizedState: DAppBrowserStateProtocol {
    func setup(with _: DAppBrowserStateDataSource) {
        stateMachine?.popMessage()
    }

    func canHandleMessage() -> Bool { true }

    func handle(message: PolkadotExtensionMessage, dataSource: DAppBrowserStateDataSource) {
        do {
            switch message.messageType {
            case .authorize:
                try provideResponse(for: message.identifier, result: true, nextState: self)
            case .accountList:
                try provideAccountListResponse(from: dataSource, requestId: message.identifier)
            case .accountSubscribe:
                try provideAccountSubscriptionResult(for: message.identifier)
            case .metadataList:
                try provideMetadataList(from: dataSource, requestId: message.identifier)
            case .metadataProvide:
                handleMetadata(from: message)
            case .signExtrinsic:
                handleExtrinsicSigning(from: message, dataSource: dataSource)
            case .signBytes:
                handleRawPayloadSigning(from: message, dataSource: dataSource)
            case .createTransaction:
                handleCreateTransaction(from: message, dataSource: dataSource)
            }
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "signing response but no request"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {
        let error = DAppBrowserStateError.unexpected(
            reason: "auth response but already authorized"
        )

        stateMachine?.emit(
            error: error,
            nextState: self
        )
    }
}

// MARK: Create transaction

private extension DAppBrowserAuthorizedState {
    struct CreateTransactionRequest {
        let operation: DAppOperationRequest
        let chain: ChainModel
    }

    func handleCreateTransaction(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        switch createTransactionRequest(from: message, dataSource: dataSource) {
        case let .success(request):
            let type: DAppSigningType = .createTransaction(chain: request.chain)
            let nextState = DAppBrowserSigningState(
                stateMachine: stateMachine,
                signingType: type,
                requestId: message.identifier
            )
            stateMachine?.emit(signingRequest: request.operation, type: type, nextState: nextState)
        case let .failure(error):
            // The dApp awaits the result of createTransaction, so the failure must settle its request
            provideError(for: message.identifier, errorMessage: error.responseMessage, nextState: self)
        }
    }

    func createTransactionRequest(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) -> Result<CreateTransactionRequest, DAppCreateTransactionError> {
        guard
            let jsonRequest = message.request,
            let payload = try? jsonRequest.map(to: PolkadotExtensionTxPayload.self) else {
            return .failure(.decodeError(details: "malformed payload"))
        }

        guard payload.version == PolkadotExtensionTxPayload.supportedVersion else {
            return .failure(.decodeError(details: "unsupported payload version \(payload.version)"))
        }

        let genesisHash = payload.context.genesisHash

        guard
            let chainId = try? Data(hexString: genesisHash).toHex(),
            let chain = dataSource.chainStore[chainId] else {
            return .failure(.signerUnavailable(details: "unsupported chain \(genesisHash)"))
        }

        guard let accountId = dataSource.wallet.fetch(for: chain.accountRequest())?.accountId else {
            return .failure(.signerUnavailable(details: "no account for chain \(genesisHash)"))
        }

        if let signer = payload.signer, accountId != signer.toCreateTransactionSignerId() {
            let details = "\(signer) is not the wallet account for chain \(genesisHash)"
            return .failure(.signerUnavailable(details: details))
        }

        let operation = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            accountId: accountId,
            dApp: message.url ?? "",
            dAppIcon: dataSource.tab?.icon,
            operationData: jsonRequest
        )

        return .success(CreateTransactionRequest(operation: operation, chain: chain))
    }
}

private extension String {
    // The dApp names the signer either with an SS58 address of any prefix or with a hex account id
    func toCreateTransactionSignerId() -> AccountId? {
        if hasPrefix("0x") {
            return try? Data(hexString: self)
        } else {
            return try? toSubstrateAccountId()
        }
    }
}
