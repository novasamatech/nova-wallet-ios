import Foundation
import IrohaCrypto

final class DAppBrowserAuthorizedState: DAppBrowserBaseState {
    private func provideAccountListResponse(from dataSource: DAppBrowserStateDataSource) throws {
        guard let accounts = try? dataSource.fetchAccountList() else {
            throw DAppBrowserStateError.unexpected(reason: "can't fetch account list")
        }

        try provideResponse(for: .accountList, result: accounts, nextState: self)
    }

    private func provideAccountSubscriptionResult(
        for requestId: String,
        dataSource _: DAppBrowserStateDataSource
    ) throws {
        let nextState = DAppBrowserAccountSubscribingState(stateMachine: stateMachine, requestId: requestId)
        try provideResponse(for: .accountSubscribe, result: true, nextState: nextState)
    }

    private func provideMetadataList(from dataSource: DAppBrowserStateDataSource) throws {
        let metadataList = dataSource.metadataStore.map { _, value in
            PolkadotExtensionMetadataResponse(genesisHash: value.genesisHash, specVersion: value.specVersion)
        }

        try provideResponse(for: .metadataList, result: metadataList, nextState: self)
    }

    private func handleMetadata(from message: PolkadotExtensionMessage) {
        if let metadata = try? message.request?.map(to: PolkadotExtensionMetadata.self) {
            let nextState = DAppBrowserMetadataState(
                stateMachine: stateMachine,
                previousState: self,
                metadata: metadata
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

        guard dataSource.wallet.fetch(for: chain.accountRequest()) != nil else {
            let error = DAppBrowserStateError.unexpected(reason: "no account for extrinsic chain")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            dApp: message.url ?? "",
            dAppIcon: dataSource.dApp?.icon,
            operationData: jsonRequest
        )

        let type: DAppSigningType = .extrinsic(chain: chain)
        let nextState = DAppBrowserSigningState(stateMachine: stateMachine, signingType: type)
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

        guard
            let accountId = try? payload.address.toAccountId(),
            let addressPrefix = try? SS58AddressFactory().type(fromAddress: payload.address).uint16Value else {
            let error = DAppBrowserStateError.unexpected(reason: "address format")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        let chains = dataSource.chainStore.values.filter {
            $0.addressPrefix == addressPrefix
        }.sorted { $0.order < $1.order }

        let maybeChain = chains.first { chain in
            dataSource.wallet.fetch(for: chain.accountRequest())?.accountId == accountId
        }

        guard let chain = maybeChain else {
            let error = DAppBrowserStateError.unexpected(reason: "raw payload chain")
            stateMachine?.emit(error: error, nextState: self)
            return
        }

        let request = DAppOperationRequest(
            transportName: DAppTransports.polkadotExtension,
            identifier: message.identifier,
            wallet: dataSource.wallet,
            dApp: message.url ?? "",
            dAppIcon: dataSource.dApp?.icon,
            operationData: .stringValue(payload.data)
        )

        let type: DAppSigningType = .bytes(chain: chain)
        let nextState = DAppBrowserSigningState(stateMachine: stateMachine, signingType: type)
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
                try provideResponse(for: .authorize, result: true, nextState: self)
            case .accountList:
                try provideAccountListResponse(from: dataSource)
            case .accountSubscribe:
                try provideAccountSubscriptionResult(for: message.identifier, dataSource: dataSource)
            case .metadataList:
                try provideMetadataList(from: dataSource)
            case .metadataProvide:
                handleMetadata(from: message)
            case .signExtrinsic:
                handleExtrinsicSigning(from: message, dataSource: dataSource)
            case .signBytes:
                handleRawPayloadSigning(from: message, dataSource: dataSource)
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
