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

    let selectedAccount: AccountItem
    let chain: Chain
    let peer: Beacon.P2PPeer
    let connectionInfo: BeaconConnectionInfo
    let logger: LoggerProtocol?

    init(
        selectedAccount: AccountItem,
        chain: Chain,
        info: BeaconConnectionInfo,
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

        self.selectedAccount = selectedAccount
        self.chain = chain
        connectionInfo = info
        self.logger = logger
    }

    deinit {
        client?.remove([.p2p(peer)], completion: { _ in })
        client?.disconnect(completion: { _ in })
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
            let account = Substrate.Account(
                network: Substrate.Network(
                    genesisHash: chain.genesisHash,
                    name: nil,
                    rpcURL: nil
                ),
                addressPrefix: Int(chain.addressType.rawValue),
                publicKey: selectedAccount.publicKeyData.toHex(includePrefix: true)
            )
            let content = try PermissionSubstrateResponse(from: permission, accounts: [account])

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
        guard let client = client else {
            return
        }

        switch blockchainRequest {
        case let .transfer(content):
            logger?.error("Unsupported transfer request")
        case let .sign(content):

            logger?.info("Signing request: \(content)")

            do {
                let request = try BeaconSigningRequest(client: client, request: content)
                presenter.didReceive(request: request)
            } catch {
                logger?.error("Did receive signing error: \(error)")
                presenter.didReceiveProtocol(error: error)
            }
        }
    }

    private func provideConnection(result: Result<Void, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.didReceiveConnection(result: result)
        }
    }
}

extension SignerConnectInteractor: SignerConnectInteractorInputProtocol, AccountFetching {
    func setup() {
        presenter.didReceiveApp(metadata: connectionInfo)
        presenter.didReceive(account: .success(selectedAccount))
    }

    func connect() {
        do {
            let matrixFactory = try Transport.P2P.Matrix.factory()
            let matrixConnection = Beacon.Connection.p2p(.init(client: matrixFactory))

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
}
