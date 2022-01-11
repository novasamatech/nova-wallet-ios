import Foundation
import IrohaCrypto

final class DAppBrowserAuthorizedState: DAppBrowserBaseState {
    private func provideAccountListResponse(from dataSource: DAppBrowserStateDataSource) throws {
        let accounts = try dataSource.fetchAccountList()

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

    private func handleMetadata(from message: PolkadotExtensionMessage) throws {
        if let metadata = try message.request?.map(to: PolkadotExtensionMetadata.self) {
            let nextState = DAppBrowserMetadataState(
                stateMachine: stateMachine,
                previousState: self,
                metadata: metadata
            )

            stateMachine?.emit(nextState: nextState)
        } else {
            stateMachine?.emit(error: DAppBrowserInteractorError.unexpectedMessageType, nextState: self)
        }
    }

    private func handleExtrinsicSigning(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) throws {
        guard
            let jsonRequest = message.request,
            let extrinsic = try? jsonRequest.map(to: PolkadotExtensionExtrinsic.self) else {
            return
        }

        guard
            let chainId = try? Data(hexString: extrinsic.genesisHash).toHex(),
            let chain = dataSource.chainStore[chainId] else {
            return
        }

        guard dataSource.wallet.fetch(for: chain.accountRequest()) != nil else {
            return
        }

        let request = DAppOperationRequest(
            identifier: message.identifier,
            wallet: dataSource.wallet,
            chain: chain,
            dApp: message.url ?? "",
            operationData: jsonRequest
        )

        let nextState = DAppBrowserSigningState(stateMachine: stateMachine, signingType: .extrinsic)
        stateMachine?.emit(signingRequest: request, nextState: nextState)
    }

    private func handleRawPayloadSigning(
        from message: PolkadotExtensionMessage,
        dataSource: DAppBrowserStateDataSource
    ) throws {
        guard let payload = try message.request?.map(to: PolkadotExtensionPayload.self) else {
            return
        }

        let accountId = try payload.address.toAccountId()
        let addressPrefix = try SS58AddressFactory().type(fromAddress: payload.address).uint16Value

        let chains = dataSource.chainStore.values.filter { $0.addressPrefix == addressPrefix }
        let maybeChain = chains.first { chain in
            dataSource.wallet.fetch(for: chain.accountRequest())?.accountId == accountId
        }

        guard let chain = maybeChain else {
            return
        }

        let request = DAppOperationRequest(
            identifier: message.identifier,
            wallet: dataSource.wallet,
            chain: chain,
            dApp: message.url ?? "",
            operationData: .stringValue(payload.data)
        )

        let nextState = DAppBrowserSigningState(stateMachine: stateMachine, signingType: .bytes)
        stateMachine?.emit(signingRequest: request, nextState: nextState)
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
                try handleMetadata(from: message)
            case .signExtrinsic:
                try handleExtrinsicSigning(from: message, dataSource: dataSource)
            case .signBytes:
                try handleRawPayloadSigning(from: message, dataSource: dataSource)
            }
        } catch {
            stateMachine?.emit(error: error, nextState: self)
        }
    }

    func handleOperation(response _: DAppOperationResponse, dataSource _: DAppBrowserStateDataSource) {}

    func handleAuth(response _: DAppAuthResponse, dataSource _: DAppBrowserStateDataSource) {}
}
