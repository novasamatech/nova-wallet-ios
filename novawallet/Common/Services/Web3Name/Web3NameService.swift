import RobinHood
import SubstrateSdk
import Foundation

typealias Web3NameSearchResult = Result<[Web3TransferRecipient], Web3NameServiceError>

protocol Web3NameServiceProtocol {
    func search(
        name: String,
        destinationChainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    )

    func cancel()

    func setup()
}

final class Web3NameService: AnyCancellableCleaning {
    @Atomic(defaultValue: nil) private var fetchRecipientsCancellableCall: CancellableCall?
    @Atomic(defaultValue: nil) private var fetchCoinListCancellableCall: CancellableCall?

    private let operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList>
    let web3NamesOperationFactory: Web3NamesOperationFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let transferRecipientRepository: Web3TransferRecipientRepositoryProtocol

    init(
        slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList>,
        web3NamesOperationFactory: Web3NamesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        transferRecipientRepository: Web3TransferRecipientRepositoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.slip44CoinsProvider = slip44CoinsProvider
        self.web3NamesOperationFactory = web3NamesOperationFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.transferRecipientRepository = transferRecipientRepository
        self.operationQueue = operationQueue
    }

    private func createRecipientWrapper(by name: String, chain: ChainModel) ->
        CompoundOperationWrapper<Web3TransferRecipientResponse?> {
        let searchNameWrapper = web3NamesOperationFactory.searchWeb3NameWrapper(
            name: name,
            service: KnownServices.transferAssetRecipient,
            connection: connection,
            runtimeService: runtimeService
        )
        let chainName = chain.name

        let recipientsWrapper: CompoundOperationWrapper<Web3TransferRecipientResponse?>
        recipientsWrapper = OperationCombiningService.compoundWrapper(
            operationManager: operationManager
        ) { [weak self] in
            guard let self = self else {
                return nil
            }
            guard let web3Name = try searchNameWrapper.targetOperation.extractNoCancellableResultData() else {
                throw Web3NameServiceError.accountNotFound(name)
            }
            guard let serviceId = web3Name.serviceId,
                  let serviceURL = web3Name.serviceURLs.first else {
                throw Web3NameServiceError.serviceNotFound(name, chainName)
            }

            return self.transferRecipientRepository.fetchRecipients(url: serviceURL, hash: serviceId)
        }

        recipientsWrapper.addDependency(wrapper: searchNameWrapper)

        let dependencies = searchNameWrapper.allOperations + recipientsWrapper.dependencies
        return .init(targetOperation: recipientsWrapper.targetOperation, dependencies: dependencies)
    }

    private func map(anyError error: Error, name: String) -> Web3NameServiceError {
        if let web3NameError = error as? Web3NameServiceError {
            return web3NameError
        } else {
            switch error as? KiltTransferAssetRecipientError {
            case .verificationFailed:
                return .integrityNotPassed(name)
            default:
                return .internalFailure(error)
            }
        }
    }

    private func searchWeb3NameRecipients(
        _ name: String,
        destinationChainAsset: ChainAsset,
        slip44CoinList: Slip44CoinList,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        let recipientsWrapper = createRecipientWrapper(by: name, chain: destinationChainAsset.chain)

        recipientsWrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, recipientsWrapper === self.fetchRecipientsCancellableCall else {
                return
            }

            self.fetchRecipientsCancellableCall = nil
            do {
                let response = try recipientsWrapper.targetOperation.extractNoCancellableResultData()
                let result = try self.handleSearchWeb3NameResult(
                    response: response,
                    name: name,
                    destinationChainAsset: destinationChainAsset,
                    slip44CoinList: slip44CoinList
                )
                completionHandler(.success(result))
            } catch {
                completionHandler(.failure(self.map(anyError: error, name: name)))
            }
        }

        fetchRecipientsCancellableCall = recipientsWrapper

        operationManager.enqueue(
            operations: recipientsWrapper.allOperations,
            in: .transient
        )
    }

    private func handleSearchWeb3NameResult(
        response: Web3TransferRecipientResponse?,
        name: String,
        destinationChainAsset: ChainAsset,
        slip44CoinList: Slip44CoinList
    ) throws -> [Web3TransferRecipient] {
        let chain = destinationChainAsset.chain
        let asset = destinationChainAsset.asset

        guard let response = response else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        guard
            let caip19Token = Caip19.RegisteredToken.createFromAsset(asset, slip44Store: slip44CoinList) else {
            throw Web3NameServiceError.tokenNotFound(token: asset.symbol)
        }

        guard let recipients = response.first(where: {
            $0.key.match(chainId: chain.chainId, token: caip19Token)
        })?.value else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        if recipients.count == 1, !recipients[0].isValid(using: chain.chainFormat) {
            throw Web3NameServiceError.invalidAddress(chain.name)
        }

        return recipients
    }
}

extension Web3NameService: Web3NameServiceProtocol {
    func setup() {
        slip44CoinsProvider.refresh()
    }

    func search(
        name: String,
        destinationChainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        var fetchCoinListWrapper: CompoundOperationWrapper<Slip44CoinList?>?
        fetchCoinListWrapper = slip44CoinsProvider.fetch { [weak self] result in
            guard fetchCoinListWrapper === self?.fetchCoinListCancellableCall else {
                return
            }
            self?.fetchCoinListCancellableCall = nil

            switch result {
            case let .success(list):
                guard let list = list, !list.isEmpty else {
                    completionHandler(.failure(.slip44ListIsEmpty))
                    return
                }
                self?.searchWeb3NameRecipients(
                    name,
                    destinationChainAsset: destinationChainAsset,
                    slip44CoinList: list,
                    completionHandler: completionHandler
                )
            case .failure, .none:
                completionHandler(.failure(.slip44ListIsEmpty))
            }
        }

        fetchCoinListCancellableCall = fetchCoinListWrapper
    }

    func cancel() {
        clear(cancellable: &fetchCoinListCancellableCall)
        clear(cancellable: &fetchRecipientsCancellableCall)
    }
}
