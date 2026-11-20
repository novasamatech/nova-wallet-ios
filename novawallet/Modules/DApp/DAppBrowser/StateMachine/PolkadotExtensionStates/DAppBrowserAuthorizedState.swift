import Foundation
import NovaCrypto
import SubstrateSdk

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

        switch resolveSigningAccount(for: extrinsic.genesisHash, dataSource: dataSource) {
        case let .success(account):
            emitSigning(
                of: .extrinsic(chain: account.chain),
                accountId: account.accountId,
                operationData: jsonRequest,
                message: message,
                dataSource: dataSource
            )
        case .failure(.invalidGenesisHash), .failure(.unknownChain):
            let error = DAppBrowserStateError.unexpected(reason: "extrinsic chain")
            stateMachine?.emit(error: error, nextState: self)
        case .failure(.noAccount):
            let error = DAppBrowserStateError.unexpected(reason: "no account for extrinsic chain")
            stateMachine?.emit(error: error, nextState: self)
        }
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

        emitSigning(
            of: .bytes(chain: chain),
            accountId: accountId,
            operationData: .stringValue(payload.data),
            message: message,
            dataSource: dataSource
        )
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

// MARK: Signing requests

private extension DAppBrowserAuthorizedState {
    struct SigningAccount {
        let chain: ChainModel
        let accountId: AccountId
    }

    enum SigningAccountError: Error {
        case invalidGenesisHash
        case unknownChain
        case noAccount
    }

    func resolveSigningAccount(
        for genesisHash: String,
        dataSource: DAppBrowserStateDataSource
    ) -> Result<SigningAccount, SigningAccountError> {
        guard let chainId = try? Data(hexString: genesisHash).toHex() else {
            return .failure(.invalidGenesisHash)
        }

        guard let chain = dataSource.chainStore[chainId] else {
            return .failure(.unknownChain)
        }

        guard let accountId = dataSource.wallet.fetch(for: chain.accountRequest())?.accountId else {
            return .failure(.noAccount)
        }

        return .success(SigningAccount(chain: chain, accountId: accountId))
    }

    func emitSigning(
        of type: DAppSigningType,
        accountId: AccountId,
        operationData: JSON,
        message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            accountId: accountId,
            dApp: message.url ?? "",
            dAppIcon: dataSource.tab?.icon,
            operationData: operationData
        )

        let nextState = DAppBrowserSigningState(
            stateMachine: stateMachine,
            signingType: type,
            requestId: message.identifier
        )

        stateMachine?.emit(signingRequest: request, type: type, nextState: nextState)
    }
}

// MARK: Create transaction

private extension DAppBrowserAuthorizedState {
    enum Constants {
        static let genesisHashField = "genesisHash"
    }

    struct CreateTransactionRequest {
        let account: SigningAccount
        let operationData: JSON
    }

    func handleCreateTransaction(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) {
        switch resolveCreateTransactionAccount(from: message.request, dataSource: dataSource) {
        case let .success(request):
            emitSigning(
                of: .createTransaction(chain: request.account.chain),
                accountId: request.account.accountId,
                operationData: request.operationData,
                message: message,
                dataSource: dataSource
            )
        case let .failure(error):
            // The dApp awaits the result of createTransaction, so the failure must settle its request
            provideFailure(for: message.identifier, error: error, nextState: self)
        }
    }

    func resolveCreateTransactionAccount(
        from jsonRequest: JSON?,
        dataSource: DAppBrowserStateDataSource
    ) -> Result<CreateTransactionRequest, DAppCreateTransactionError> {
        guard
            let jsonRequest,
            let payload = try? jsonRequest.map(to: PolkadotExtensionTxPayload.self) else {
            return .failure(.decodeError(details: "malformed payload"))
        }

        guard payload.version == PolkadotExtensionTxPayload.supportedVersion else {
            return .failure(.decodeError(details: "unsupported payload version \(payload.version)"))
        }

        let genesisHash = payload.context.genesisHash

        switch resolveSigningAccount(for: genesisHash, dataSource: dataSource) {
        case let .success(account):
            if let signer = payload.signer, account.accountId != (try? signer.toSubstrateAccountIdOrHex()) {
                let details = "\(signer) is not the wallet account for chain \(genesisHash)"
                return .failure(.signerUnavailable(details: details))
            }

            return .success(CreateTransactionRequest(account: account, operationData: jsonRequest))
        case .failure(.invalidGenesisHash):
            return .failure(.invalidHex(details: Constants.genesisHashField))
        case .failure(.unknownChain):
            return .failure(.signerUnavailable(details: "unsupported chain \(genesisHash)"))
        case .failure(.noAccount):
            return .failure(.signerUnavailable(details: "no account for chain \(genesisHash)"))
        }
    }
}
