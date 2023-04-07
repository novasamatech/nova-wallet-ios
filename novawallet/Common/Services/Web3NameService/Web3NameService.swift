import RobinHood
import SubstrateSdk

typealias Web3NameSearchResult = Result<[Web3NameTransferAssetRecipientAccount], Web3NameServiceError>

protocol Web3NameServiceProtocol {
    func search(
        name: String,
        chainAsset: ChainAsset,
        originAsset: AssetModel,
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
    let kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol

    init(
        slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList>,
        web3NamesOperationFactory: Web3NamesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.slip44CoinsProvider = slip44CoinsProvider
        self.web3NamesOperationFactory = web3NamesOperationFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.kiltTransferAssetRecipientRepository = kiltTransferAssetRecipientRepository
        self.operationQueue = operationQueue
    }

    private func kiltRecipient(by name: String, chain: ChainModel) ->
        CompoundOperationWrapper<TransferAssetRecipientResponse?> {
        let searchNameWrapper = web3NamesOperationFactory.searchWeb3NameWrapper(
            name: name,
            service: KnownServices.transferAssetRecipient,
            connection: connection,
            runtimeService: runtimeService
        )
        let chainName = chain.name

        let recipientsWrapper: CompoundOperationWrapper<TransferAssetRecipientResponse?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }
                guard let web3Name = try searchNameWrapper.targetOperation.extractNoCancellableResultData() else {
                    throw Web3NameServiceError.accountNotFound(name)
                }
                guard let serviceURL = web3Name.serviceURLs.last else {
                    throw Web3NameServiceError.serviceNotFound(name, chainName)
                }

                return self.kiltTransferAssetRecipientRepository.fetchRecipients(url: serviceURL)
            }

        recipientsWrapper.addDependency(wrapper: searchNameWrapper)

        let dependencies = searchNameWrapper.allOperations + recipientsWrapper.dependencies
        return .init(targetOperation: recipientsWrapper.targetOperation, dependencies: dependencies)
    }

    private func searchWeb3NameRecipients(
        _ name: String,
        chainAsset: ChainAsset,
        originAsset: AssetModel,
        slip44CoinList: Slip44CoinList,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        let recipientsWrapper = kiltRecipient(by: name, chain: chainAsset.chain)

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
                    chainAsset: chainAsset,
                    originAsset: originAsset,
                    slip44CoinList: slip44CoinList
                )
                completionHandler(.success(result))
            } catch let error as Web3NameServiceError {
                completionHandler(.failure(error))
            } catch {
                completionHandler(.failure(Web3NameServiceError.kiltService(error)))
            }
        }

        fetchRecipientsCancellableCall = recipientsWrapper

        operationManager.enqueue(
            operations: recipientsWrapper.allOperations,
            in: .transient
        )
    }

    private func handleSearchWeb3NameResult(
        response: TransferAssetRecipientResponse?,
        name: String,
        chainAsset: ChainAsset,
        originAsset: AssetModel,
        slip44CoinList: Slip44CoinList
    ) throws -> [Web3NameTransferAssetRecipientAccount] {
        let chain = chainAsset.chain

        guard let response = response else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        guard let coin = slip44CoinList.first(where: {
            $0.symbol == chainAsset.asset.symbol
        }) ?? slip44CoinList.first(where: {
            $0.symbol == originAsset.symbol
        }), let slip44Code = Int(coin.index) else {
            throw Web3NameServiceError.slip44CodeNotFound(token: chainAsset.asset.symbol)
        }

        guard let recipients = response.first(where: {
            $0.key.chainId.match(chain.chainId) && slip44Code == $0.key.slip44Code
        })?.value else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        if recipients.count == 1,
           !recipients[0].isValid(using: chain.chainFormat) {
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
        chainAsset: ChainAsset,
        originAsset: AssetModel,
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
                    chainAsset: chainAsset,
                    originAsset: originAsset,
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
