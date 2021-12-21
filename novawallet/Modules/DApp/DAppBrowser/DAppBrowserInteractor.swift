import UIKit
import RobinHood

enum DAppBrowserInteractorError: Error {
    case scriptFileMissing
    case invalidUrl
    case unexpectedMessageType
}

enum DAppBrowserInteractorState {
    case setup
    case ready
    case pendingAuth
    case pendingOperation
}

final class DAppBrowserInteractor {
    static let subscriptionName = "_nova_"

    weak var presenter: DAppBrowserInteractorOutputProtocol!

    let userInput: String
    let wallet: MetaAccountModel
    let operationQueue: OperationQueue
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    private var chainStore: [String: ChainModel] = [:]

    private(set) var state: DAppBrowserInteractorState = .setup

    init(
        userInput: String,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.userInput = userInput
        self.wallet = wallet
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
        self.logger = logger
    }

    private func subscribeChainRegistry() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            for change in changes {
                switch change {
                case let .insert(newItem):
                    self?.chainStore[newItem.chainId] = newItem
                case let .update(newItem):
                    self?.chainStore[newItem.chainId] = newItem
                case let .delete(deletedIdentifier):
                    self?.chainStore[deletedIdentifier] = nil
                }
            }

            self?.completeSetupIfNeeded()
        }
    }

    private func completeSetupIfNeeded() {
        if case .setup = state, !chainStore.isEmpty {
            state = .ready
            provideModel()
        }
    }

    private func createBridgeScriptOperation() -> BaseOperation<DAppBrowserScript> {
        ClosureOperation<DAppBrowserScript> {
            guard let url = R.file.nova_minJs.url() else {
                throw DAppBrowserInteractorError.scriptFileMissing
            }

            let content = try String(contentsOf: url)

            return DAppBrowserScript(content: content, insertionPoint: .atDocStart)
        }
    }

    private func createSubscriptionScript() -> DAppBrowserScript {
        let content =
            """
            window.addEventListener("message", ({ data, source }) => {
              // only allow messages from our window, by the loader
              if (source !== window) {
                return;
              }

              if (data.origin === "dapp-request") {
                window.webkit.messageHandlers.\(Self.subscriptionName).postMessage(data);
              }
            });
            """

        let script = DAppBrowserScript(content: content, insertionPoint: .atDocEnd)
        return script
    }

    func provideModel() {
        let maybeUrl: URL? = {
            if NSPredicate.urlPredicate.evaluate(with: userInput), let inputUrl = URL(string: userInput) {
                return inputUrl
            } else {
                let querySet = CharacterSet.urlQueryAllowed
                guard let searchQuery = userInput.addingPercentEncoding(withAllowedCharacters: querySet) else {
                    return nil
                }

                return URL(string: "https://www.google.com/search?q=\(searchQuery)")
            }
        }()

        guard let url = maybeUrl else {
            presenter.didReceive(error: DAppBrowserInteractorError.invalidUrl)
            return
        }

        let bridgeOperation = createBridgeScriptOperation()
        let subscriptionScript = createSubscriptionScript()

        bridgeOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let bridgeScript = try bridgeOperation.extractNoCancellableResultData()

                    let model = DAppBrowserModel(
                        url: url,
                        subscriptionName: Self.subscriptionName,
                        scripts: [bridgeScript, subscriptionScript]
                    )

                    self?.presenter.didReceiveDApp(model: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(bridgeOperation)
    }

    private func provideResponse<T: Encodable>(
        for messageType: PolkadotExtensionMessage.MessageType,
        result: T
    ) throws {
        let data = try JSONEncoder().encode(result)

        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        let content = String(
            format: "window.walletExtension.onAppResponse(\"%@\", %@, null)", messageType.rawValue, dataString
        )

        let response = PolkadotExtensionResponse(content: content)

        presenter.didReceive(response: response)
    }

    private func createExtensionAccount(
        for accountId: AccountId,
        genesisHash: Data?,
        name: String,
        chainFormat: ChainFormat,
        rawCryptoType: UInt8
    ) throws -> PolkadotExtensionAccount {
        let address = try accountId.toAddress(using: chainFormat)

        let keypairType: PolkadotExtensionKeypairType?
        if let substrateCryptoType = MultiassetCryptoType(rawValue: rawCryptoType) {
            keypairType = PolkadotExtensionKeypairType(cryptoType: substrateCryptoType)
        } else {
            keypairType = nil
        }

        return PolkadotExtensionAccount(
            address: address,
            genesisHash: genesisHash?.toHex(includePrefix: true),
            name: name,
            type: keypairType
        )
    }

    private func provideAccountListResponse() throws {
        let substrateAccount = try createExtensionAccount(
            for: wallet.substrateAccountId,
            genesisHash: nil,
            name: wallet.name,
            chainFormat: .substrate(42),
            rawCryptoType: wallet.substrateCryptoType
        )

        let chainAccounts: [PolkadotExtensionAccount] = try wallet.chainAccounts.compactMap { chainAccount in
            guard let chain = chainStore[chainAccount.chainId], !chain.isEthereumBased else {
                return nil
            }

            let genesisHash = try Data(hexString: chain.chainId)
            let name = wallet.name + " (\(chain.name))"

            return try createExtensionAccount(
                for: chainAccount.accountId,
                genesisHash: genesisHash,
                name: name,
                chainFormat: chain.chainFormat,
                rawCryptoType: chainAccount.cryptoType
            )
        }

        try provideResponse(for: .accountList, result: [substrateAccount] + chainAccounts)
    }

    private func handleExtrinsic(message: PolkadotExtensionMessage) {
        guard case .ready = state else {
            return
        }

        guard
            let jsonRequest = message.request,
            let extrinsic = try? jsonRequest.map(to: PolkadotExtensionExtrinsic.self) else {
            return
        }

        guard
            let chainId = try? Data(hexString: extrinsic.genesisHash).toHex(),
            let chain = chainStore[chainId] else {
            return
        }

        guard wallet.fetch(for: chain.accountRequest()) != nil else {
            return
        }

        let request = DAppOperationRequest(
            identifier: message.identifier,
            wallet: wallet,
            chain: chain,
            dApp: "",
            operationData: jsonRequest
        )

        presenter?.didReceiveConfirmation(request: request)
    }
}

extension DAppBrowserInteractor: DAppBrowserInteractorInputProtocol {
    func setup() {
        subscribeChainRegistry()
    }

    func process(message: Any) {
        guard let dict = message as? NSDictionary else {
            presenter.didReceive(error: DAppBrowserInteractorError.unexpectedMessageType)
            return
        }

        do {
            logger?.info("Did receive message: \(dict)")

            let parsedMessage = try dict.map(to: PolkadotExtensionMessage.self)

            switch parsedMessage.messageType {
            case .authorize:
                try provideResponse(for: .authorize, result: true)
            case .accountList:
                try provideAccountListResponse()
            case .accountSubscribe:
                break
            case .metadataList:
                break
            case .metadataProvide:
                break
            case .signBytes:
                break
            case .signExtrinsic:
                handleExtrinsic(message: parsedMessage)
            }
        } catch {
            presenter.didReceive(error: error)
        }
    }

    func processConfirmation(response _: DAppOperationResponse) {}
}
