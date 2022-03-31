import UIKit
import BeaconCore
import BeaconClientWallet
import BeaconBlockchainSubstrate
import BeaconTransportP2PMatrix
import IrohaCrypto
import RobinHood
import SubstrateSdk

final class SignerConnectInteractor {
    weak var presenter: SignerConnectInteractorOutputProtocol!

    private var client: Beacon.WalletClient?

    let wallet: MetaAccountModel
    let peer: Beacon.P2PPeer
    let connectionInfo: BeaconConnectionInfo
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    private var availableChains: [Data: ChainModel] = [:]
    private var pendingRequests: [String: BlockchainSubstrateRequest] = [:]
    private var isSetuping: Bool = true

    init(
        wallet: MetaAccountModel,
        info: BeaconConnectionInfo,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        peer = Beacon.P2PPeer(
            id: info.identifier,
            name: info.name,
            publicKey: info.publicKey,
            relayServer: info.relayServer,
            version: info.name,
            icon: info.icon,
            appURL: nil
        )

        self.wallet = wallet
        connectionInfo = info
        self.chainRegistry = chainRegistry
        self.logger = logger
    }

    deinit {
        client?.remove([.p2p(peer)], completion: { _ in })
        client?.disconnect(completion: { _ in })
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            self?.process(changes: changes)
        }
    }

    private func process(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                if let rawId = try? Data(hexString: newItem.identifier) {
                    availableChains[rawId] = newItem
                }
            case let .delete(deletedIdentifier):
                if let rawId = try? Data(hexString: deletedIdentifier) {
                    availableChains[rawId] = nil
                }
            }
        }

        if !changes.isEmpty, isSetuping {
            completeSetup()
        }
    }

    private func completeSetup() {
        isSetuping = false

        presenter.didReceiveApp(metadata: connectionInfo)
        presenter.didReceive(wallet: wallet)
    }

    private func connect(using client: Beacon.WalletClient) {
        self.client = client

        logger?.debug("Did create client")

        client.connect { [weak self] result in
            switch result {
            case .success:
                self?.logger?.debug("Did connect")
                self?.addPeer()
            case let .failure(error):
                self?.logger?.error("Could not connect, got error: \(error)")
                self?.client = nil
                self?.provideConnection(result: .failure(error))
            }
        }
    }

    private func addPeer() {
        logger?.debug("Will add peer")

        client?.add([.p2p(peer)]) { [weak self] result in
            switch result {
            case .success:
                self?.logger?.debug("Did add peer")
                self?.provideConnection(result: .success(()))
                self?.startListenRequests()
            case let .failure(error):
                self?.logger?.error("Error while adding peer: \(error)")
                self?.client = nil
                self?.provideConnection(result: .failure(error))
            }
        }
    }

    private func startListenRequests() {
        logger?.debug("Will start listen requests")

        client?.listen { [weak self] (result: Result<BeaconRequest<Substrate>, Beacon.Error>) in
            self?.onBeaconRequest(result: result)
        }
    }

    private func onBeaconRequest(result: Result<BeaconRequest<Substrate>, Beacon.Error>) {
        switch result {
        case let .success(request):
            DispatchQueue.main.async {
                self.handle(request: request)
            }
        case let .failure(error):
            logger?.error("Error while processing incoming messages: \(error)")

            DispatchQueue.main.async {
                self.presenter.didReceiveProtocol(error: error)
            }
        }
    }

    private func handle(request: BeaconRequest<Substrate>) {
        switch request {
        case let .permission(permission):
            handle(permission: permission)
        case let .blockchain(substrateRequest):
            handle(blockchainRequest: substrateRequest)
        }
    }

    private func handle(permission: PermissionSubstrateRequest) {
        logger?.debug("Permission request: \(permission)")

        do {
            let networkAccounts: [Substrate.Account] = try permission.networks.compactMap { network in
                let rawId = try Data(hexString: network.genesisHash)

                if let chain = availableChains[rawId] {
                    guard
                        let accountResponse = wallet.fetch(for: chain.accountRequest()),
                        let address = accountResponse.toAddress() else {
                        return nil
                    }

                    return try Substrate.Account(
                        publicKey: accountResponse.publicKey.toHex(includePrefix: true),
                        address: address,
                        network: Substrate.Network(
                            genesisHash: network.genesisHash,
                            name: chain.name,
                            rpcURL: chain.nodes.first?.url.absoluteString
                        )
                    )
                } else {
                    return nil
                }
            }

            let universalAddress = try wallet.substrateAccountId.toAddress(using: .substrate(42))
            let universalAccount = try Substrate.Account(
                publicKey: wallet.substratePublicKey.toHex(includePrefix: true),
                address: universalAddress
            )

            let accounts = networkAccounts + [universalAccount]

            let content = PermissionSubstrateResponse(from: permission, accounts: accounts)

            let response = BeaconResponse<Substrate>.permission(content)

            client?.respond(with: response) { [weak self] result in
                switch result {
                case .success:
                    self?.logger?.debug("Permission response submitted")
                case let .failure(error):
                    self?.logger?.error("Did receive permission error: \(error)")
                }
            }
        } catch {
            logger?.error("Unexpected permission error: \(error)")
        }
    }

    private func handle(blockchainRequest: BlockchainSubstrateRequest) {
        switch blockchainRequest {
        case .transfer:
            logger?.error("Unsupported transfer request")
        case let .signPayload(content):

            logger?.info("Signing request: \(content)")

            guard let (signingType, operationJson) = createOperation(from: content) else {
                logger?.error("Can't parse operation data from signed payload")
                return
            }

            let dAppUrl = connectionInfo.icon.flatMap { URL(string: $0) }
            let signingRequest = DAppOperationRequest(
                transportName: "beacon",
                identifier: blockchainRequest.id,
                wallet: wallet,
                dApp: connectionInfo.name,
                dAppIcon: dAppUrl,
                operationData: operationJson
            )

            pendingRequests[blockchainRequest.id] = blockchainRequest

            presenter.didReceive(request: signingRequest, signingType: signingType)
        }
    }

    private func provideConnection(result: Result<Void, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.didReceiveConnection(result: result)
        }
    }

    private func createOperation(
        from content: SignPayloadSubstrateRequest
    ) -> (DAppSigningType, JSON)? {
        switch content.payload {
        case let .raw(rawPayload):
            if
                let addressPrefix = try? SS58AddressFactory().type(fromAddress: content.address),
                let chain = availableChains.values.sorted(by: { $0.order < $1.order }).first(
                    where: {
                        $0.addressPrefix == addressPrefix.uint16Value &&
                            chainRegistry.getRuntimeProvider(for: $0.chainId) != nil
                    }
                ) {
                let signingType = DAppSigningType.rawExtrinsic(chain: chain)
                return (signingType, JSON.stringValue(rawPayload.data))
            } else {
                return nil
            }
        case let .json(json):
            let extensionModel = PolkadotExtensionExtrinsic(
                address: content.address,
                blockHash: json.blockHash,
                blockNumber: json.blockNumber,
                era: json.era,
                genesisHash: json.genesisHash,
                method: json.method,
                nonce: json.nonce,
                specVersion: json.specVersion,
                tip: json.tip,
                transactionVersion: json.transactionVersion,
                signedExtensions: json.signedExtensions,
                version: UInt(json.version)
            )

            if
                let rawId = try? Data(hexString: json.genesisHash),
                let chain = availableChains[rawId],
                let rawJson = try? extensionModel.toScaleCompatibleJSON(with: nil) {
                return (DAppSigningType.extrinsic(chain: chain), rawJson)
            } else {
                return nil
            }
        }
    }

    private func submitPayloadSignature(
        _ signatureData: Data,
        request: SignPayloadSubstrateRequest
    ) {
        do {
            let content = try ReturnSignPayloadSubstrateResponse(
                from: request,
                signature: signatureData.toHex(includePrefix: true)
            )

            let response = BeaconResponse<Substrate>.blockchain(
                .signPayload(SignPayloadSubstrateResponse.return(content))
            )

            client?.respond(with: response) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.logger?.info("Signature submited")
                        self?.presenter.didSubmitOperation()
                    case let .failure(error):
                        self?.logger?.error("Signature submition failed: \(error)")
                        self?.presenter.didReceiveProtocol(error: error)
                    }
                }
            }
        } catch {
            let errorType = Beacon.ErrorType<Substrate>.aborted

            let remoteRequest = BlockchainSubstrateRequest.signPayload(request)

            let errorContent = ErrorBeaconResponse<Substrate>.init(
                from: remoteRequest,
                errorType: errorType,
                description: nil
            )

            let response = BeaconResponse<Substrate>.error(errorContent)
            client?.respond(with: response, completion: { _ in })

            logger?.info("Signing aborted: \(error)")
            presenter.didReceiveProtocol(error: error)
        }
    }

    private func submitSignature(_ signatureData: Data, for request: BlockchainSubstrateRequest) {
        switch request {
        case .transfer:
            logger?.warning("Transfer signing is not supported")
        case let .signPayload(content):
            submitPayloadSignature(signatureData, request: content)
        }
    }

    private func submitRejection(request: BlockchainSubstrateRequest) {
        let errorType = Beacon.ErrorType<Substrate>.aborted
        let errorContent: ErrorBeaconResponse<Substrate>

        switch request {
        case let .transfer(content):
            let remoteRequest = BlockchainSubstrateRequest.transfer(content)

            errorContent = ErrorBeaconResponse<Substrate>.init(
                from: remoteRequest,
                errorType: errorType,
                description: nil
            )
        case let .signPayload(content):
            let remoteRequest = BlockchainSubstrateRequest.signPayload(content)

            errorContent = ErrorBeaconResponse<Substrate>.init(
                from: remoteRequest,
                errorType: errorType,
                description: nil
            )
        }

        let response = BeaconResponse<Substrate>.error(errorContent)
        client?.respond(with: response, completion: { _ in })

        logger?.info("Signing rejected")
    }
}

extension SignerConnectInteractor: SignerConnectInteractorInputProtocol, AccountFetching {
    func setup() {
        subscribeChains()
    }

    func connect() {
        do {
            let matrixConnection = try Transport.P2P.Matrix.connection()

            Beacon.WalletClient.create(with: Beacon.WalletClient.Configuration(
                name: "Nova Wallet",
                blockchains: [Substrate.factory],
                connections: [matrixConnection]
            )) { [weak self] result in
                switch result {
                case let .success(client):
                    self?.connect(using: client)
                case let .failure(error):
                    self?.logger?.error("Could not create Beacon client, got error: \(error)")
                }
            }
        } catch {
            logger?.error("Could not create matrix transport, got error: \(error)")
        }
    }

    func processSigning(response: DAppOperationResponse, for request: DAppOperationRequest) {
        guard let blockchainRequest = pendingRequests[request.identifier] else {
            logger?.warning("Can't find pending request for id: \(request.identifier)")
            return
        }

        if let signature = response.signature {
            submitSignature(signature, for: blockchainRequest)
        } else {
            submitRejection(request: blockchainRequest)
        }
    }
}
