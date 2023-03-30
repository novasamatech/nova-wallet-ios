import RobinHood
import SubstrateSdk

typealias Web3NameSearchResult = Result<[KiltTransferAssetRecipientAccount], Web3NameServiceError>

protocol Web3NameServiceProtocol {
    func search(
        name: String,
        for chainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    )
    func cancel()
}

final class Web3NameService: AnyCancellableCleaning {
    @Atomic(defaultValue: nil) private var executingOperation: CancellableCall?

    private let operationQueue: OperationQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    let slip44CoinsRepository: Slip44CoinRepositoryProtocol
    let web3NamesOperationFactory: Web3NamesOperationFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol

    init(
        slip44CoinsRepository: Slip44CoinRepositoryProtocol,
        web3NamesOperationFactory: Web3NamesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.slip44CoinsRepository = slip44CoinsRepository
        self.web3NamesOperationFactory = web3NamesOperationFactory
        self.runtimeService = runtimeService
        self.connection = connection
        self.kiltTransferAssetRecipientRepository = kiltTransferAssetRecipientRepository
        self.operationQueue = operationQueue
    }

    private func fetchSlip44CoinListWrapper() -> BaseOperation<Slip44CoinList> {
        slip44CoinsRepository.fetchCoinList()
    }

    private func kiltRecipient(by name: String, for chainAsset: ChainAsset) ->
        CompoundOperationWrapper<TransferAssetRecipientResponse?> {
        let searchNameWrapper = web3NamesOperationFactory.searchWeb3NameWrapper(
            name: name,
            service: KnownServices.transferAssetRecipient,
            connection: connection,
            runtimeService: runtimeService
        )
        let chainName = chainAsset.chain.name

        let recipientsWrapper: CompoundOperationWrapper<TransferAssetRecipientResponse?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }

                guard let web3Name = try searchNameWrapper.targetOperation.extractNoCancellableResultData() else {
                    throw Web3NameServiceError.accountNotFound(name)
                }
                guard let serviceURL = web3Name.serviceURLs.first else {
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
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        let slip44CoinListOperation = fetchSlip44CoinListWrapper()
        let recipientsWrapper = kiltRecipient(by: name, for: chainAsset)

        let mergeOperation = ClosureOperation {
            let coinList = try slip44CoinListOperation.extractNoCancellableResultData()
            let recipients = try recipientsWrapper.targetOperation.extractNoCancellableResultData()
            return try self.handleSearchWeb3NameResult(
                response: recipients,
                name: name,
                chainAsset: chainAsset,
                slip44CoinList: coinList
            )
        }

        let dependencies = [slip44CoinListOperation] + recipientsWrapper.allOperations
        dependencies.forEach { mergeOperation.addDependency($0) }

        mergeOperation.completionBlock = { [weak self] in
            guard mergeOperation === self?.executingOperation else {
                return
            }
            self?.executingOperation = nil
            do {
                let result = try mergeOperation.extractNoCancellableResultData()
                completionHandler(.success(result))
            } catch let error as Web3NameServiceError {
                completionHandler(.failure(error))
            } catch {
                completionHandler(.failure(Web3NameServiceError.kiltService(error)))
            }
        }

        executingOperation = mergeOperation

        operationManager.enqueue(
            operations: dependencies + [mergeOperation],
            in: .transient
        )
    }

    private func handleSearchWeb3NameResult(
        response: TransferAssetRecipientResponse?,
        name: String,
        chainAsset: ChainAsset,
        slip44CoinList: Slip44CoinList
    ) throws -> [KiltTransferAssetRecipientAccount] {
        let chain = chainAsset.chain

        guard
            let response = response,
            let coin = slip44CoinList.first(where: {
                $0.symbol == chainAsset.asset.symbol
            }),
            let slip44Code = Int(coin.index)
        else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        guard let recipients = response.first(where: {
            $0.key.chainId.match(chainAsset.chain.chainId) && slip44Code == $0.key.slip44Code
        })?.value else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        if recipients.count == 1,
           (try? recipients[0].account.toAccountId(using: chain.chainFormat)) == nil {
            throw Web3NameServiceError.invalidAddress(chain.name)
        }

        return recipients
    }
}

extension Web3NameService: Web3NameServiceProtocol {
    func search(
        name: String,
        for chainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        searchWeb3NameRecipients(name, chainAsset: chainAsset, completionHandler: completionHandler)
    }

    func cancel() {
        clear(cancellable: &executingOperation)
    }
}
