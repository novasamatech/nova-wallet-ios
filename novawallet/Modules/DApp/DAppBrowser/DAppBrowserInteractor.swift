import UIKit
import RobinHood

enum DAppBrowserInteractorError: Error {
    case scriptFileMissing
    case invalidUrl
    case unexpectedMessageType
    case specVersionMismatch
}

enum DAppBrowserInteractorState {
    case setup
    case waitingAuth
    case pendingAuth
    case authorized
    case denied
    case pendingOperation(queue: [DAppOperationRequest])
}

final class DAppBrowserInteractor {
    static let subscriptionName = "_nova_"

    weak var presenter: DAppBrowserInteractorOutputProtocol!

    private(set) var userQuery: DAppUserQuery
    let wallet: MetaAccountModel
    let operationQueue: OperationQueue
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol?

    private var chainStore: [String: ChainModel] = [:]
    private var metadataStore: [String: PolkadotExtensionMetadata] = [:]

    private(set) var state: DAppBrowserInteractorState = .setup

    init(
        userQuery: DAppUserQuery,
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.userQuery = userQuery
        self.wallet = wallet
        self.operationQueue = operationQueue
        self.chainRegistry = chainRegistry
        self.logger = logger
    }

    private func fetchAccountList() throws -> [PolkadotExtensionAccount] {
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

        return [substrateAccount] + chainAccounts
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
            state = .waitingAuth
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
            switch userQuery {
            case let .url(url):
                return url
            case let .search(query):
                if NSPredicate.urlPredicate.evaluate(with: query), let inputUrl = URL(string: query) {
                    return inputUrl
                } else {
                    let querySet = CharacterSet.urlQueryAllowed
                    guard let searchQuery = query.addingPercentEncoding(withAllowedCharacters: querySet) else {
                        return nil
                    }

                    return URL(string: "https://duckduckgo.com/?q=\(searchQuery)")
                }
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

    private func provideError(
        for messageType: PolkadotExtensionMessage.MessageType,
        errorMessage: String
    ) {
        let content = String(
            format: "window.walletExtension.onAppResponse(\"%@\", null, new Error(\"%@\"))",
            messageType.rawValue, errorMessage
        )

        let response = PolkadotExtensionResponse(content: content)

        presenter.didReceive(response: response)
    }

    private func provideSubscription<T: Encodable>(
        for requestId: String,
        result: T
    ) throws {
        let data = try JSONEncoder().encode(result)

        guard let dataString = String(data: data, encoding: .utf8) else {
            return
        }

        let content = String(
            format: "window.walletExtension.onAppSubscription(\"%@\", %@)", requestId, dataString
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
        let accounts = try fetchAccountList()

        try provideResponse(for: .accountList, result: accounts)
    }

    private func provideAccountSubscriptionResult(for requestId: String) throws {
        let accounts = try fetchAccountList()

        try provideResponse(for: .accountSubscribe, result: true)
        try provideSubscription(for: requestId, result: accounts)
    }

    private func provideOperationResponse(with signature: Data) throws {
        let identifier = (0 ... UInt32.max).randomElement() ?? 0
        let result = PolkadotExtensionSignerResult(
            identifier: UInt(identifier),
            signature: signature.toHex(includePrefix: true)
        )

        try provideResponse(for: .signExtrinsic, result: result)
    }

    private func providerOperationError(_ error: PolkadotExtensionError) {
        provideError(for: .signExtrinsic, errorMessage: error.rawValue)
    }

    private func handleExtrinsic(message: PolkadotExtensionMessage) {
        switch state {
        case .setup, .waitingAuth, .pendingAuth, .denied:
            break
        case .authorized, .pendingOperation:
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
                dApp: message.url ?? "",
                operationData: jsonRequest
            )

            handleOperation(request: request)
        }
    }

    private func handleAuth(message: PolkadotExtensionMessage) throws {
        switch state {
        case .setup, .pendingAuth, .denied:
            break
        case .waitingAuth:
            let request = DAppAuthRequest(
                identifier: message.identifier,
                wallet: wallet,
                dApp: message.url ?? ""
            )

            state = .pendingAuth

            presenter.didReceiveAuth(request: request)
        case .authorized, .pendingOperation:
            try provideResponse(for: .authorize, result: true)
        }
    }

    private func handleAccountList(message: PolkadotExtensionMessage) throws {
        switch state {
        case .authorized, .pendingOperation:
            try provideAccountListResponse()
        case .setup, .waitingAuth, .pendingAuth, .denied:
            provideError(for: message.messageType, errorMessage: PolkadotExtensionError.rejected.rawValue)
        }
    }

    private func handleAccountSubscribe(message: PolkadotExtensionMessage) throws {
        switch state {
        case .authorized, .pendingOperation:
            try provideAccountSubscriptionResult(for: message.identifier)
        case .setup, .waitingAuth, .pendingAuth, .denied:
            provideError(for: message.messageType, errorMessage: PolkadotExtensionError.rejected.rawValue)
        }
    }

    private func handleMetadataList(message _: PolkadotExtensionMessage) throws {
        switch state {
        case .setup, .pendingAuth, .waitingAuth, .denied:
            return
        case .authorized, .pendingOperation:
            let metadataList = metadataStore.map { _, value in
                PolkadotExtensionMetadataResponse(
                    genesisHash: value.genesisHash,
                    specVersion: value.specVersion
                )
            }

            try provideResponse(for: .metadataList, result: metadataList)
        }
    }

    private func handleProvidedMetadata(message: PolkadotExtensionMessage) throws {
        switch state {
        case .setup, .pendingAuth, .waitingAuth, .denied:
            return
        case .authorized, .pendingOperation:
            guard let request = try message.request?.map(to: PolkadotExtensionMetadata.self) else {
                return
            }

            let genesisHash = try Data(hexString: request.genesisHash)

            validate(specVersion: request.specVersion, for: genesisHash)
        }
    }

    private func handleOperation(request: DAppOperationRequest) {
        switch state {
        case .setup, .waitingAuth, .pendingAuth, .denied:
            break
        case .authorized:
            state = .pendingOperation(queue: [])
            presenter?.didReceiveConfirmation(request: request)
        case let .pendingOperation(queue):
            state = .pendingOperation(queue: queue + [request])
        }
    }

    private func validate(specVersion: UInt32, for genesisHashData: Data) {
        let chainId = genesisHashData.toHex()

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            provideError(
                for: .metadataProvide,
                errorMessage: PolkadotExtensionError.unsupported.rawValue
            )
            return
        }

        let operation = runtimeProvider.fetchCoderFactoryOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let coderFactory = try operation.extractNoCancellableResultData()

                    if coderFactory.specVersion != specVersion {
                        self?.provideError(
                            for: .metadataProvide,
                            errorMessage: PolkadotExtensionError.unsupported.rawValue
                        )
                    } else {
                        let genesisHash = genesisHashData.toHex(includePrefix: true)

                        let metadata = PolkadotExtensionMetadata(
                            genesisHash: genesisHash,
                            specVersion: specVersion
                        )

                        self?.metadataStore[genesisHash] = metadata

                        try self?.provideResponse(for: .metadataProvide, result: true)
                    }

                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(operation)
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
                try handleAuth(message: parsedMessage)
            case .accountList:
                try handleAccountList(message: parsedMessage)
            case .accountSubscribe:
                try handleAccountSubscribe(message: parsedMessage)
            case .metadataList:
                try handleMetadataList(message: parsedMessage)
            case .metadataProvide:
                try handleProvidedMetadata(message: parsedMessage)
            case .signBytes:
                break
            case .signExtrinsic:
                handleExtrinsic(message: parsedMessage)
            }
        } catch {
            presenter.didReceive(error: error)
        }
    }

    func processConfirmation(response: DAppOperationResponse) {
        guard case let .pendingOperation(queue) = state else {
            return
        }

        let maybeRequest = queue.first

        if maybeRequest != nil {
            let nextQueue = Array(queue.dropFirst())
            state = .pendingOperation(queue: nextQueue)
        } else {
            state = .authorized
        }

        if let signature = response.signature {
            do {
                try provideOperationResponse(with: signature)
            } catch {
                presenter.didReceive(error: error)
            }
        } else {
            providerOperationError(.rejected)
        }

        if let nextRequest = maybeRequest {
            handleOperation(request: nextRequest)
        }
    }

    func process(newQuery: String) {
        if case .setup = state {
            return
        }

        userQuery = .search(newQuery)
        state = .waitingAuth

        provideModel()
    }

    func processAuth(response: DAppAuthResponse) {
        guard case .pendingAuth = state else {
            return
        }

        state = response.approved ? .authorized : .denied

        do {
            if response.approved {
                try provideResponse(for: .authorize, result: response.approved)
            } else {
                provideError(for: .authorize, errorMessage: PolkadotExtensionError.rejected.rawValue)
            }

        } catch {
            presenter.didReceive(error: error)
        }
    }
}
