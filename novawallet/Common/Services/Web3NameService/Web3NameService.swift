import RobinHood
import SubstrateSdk

typealias Web3NameSearchResult = Result<[KiltTransferAssetRecipientAccount], TransferSetupWeb3NameSearchError>

protocol Web3NameServiceProtocol {
    func search(w3nName: String,
                for chainAsset: ChainAsset,
                completionHandler: @escaping (Web3NameSearchResult) -> Void)
    func cancel()
}

final class Web3NameService: AnyCancellableCleaning, Web3NameServiceProtocol {
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
        slip44CoinsRepository.fetch()
    }

    private func kiltRecipient(by name: String, for chainAsset: ChainAsset) -> CompoundOperationWrapper<TransferAssetRecipientResponse?> {
        let web3NamesWrapper = web3NamesOperationFactory.searchWeb3NameWrapper(
            name: name,
            service: KnownServices.transferAssetRecipient,
            connection: connection,
            runtimeService: runtimeService
        )
        let chainName = chainAsset.chain.name

        let wrapper: CompoundOperationWrapper<TransferAssetRecipientResponse?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }

                guard let web3Name = try web3NamesWrapper.targetOperation.extractNoCancellableResultData() else {
                    throw TransferSetupWeb3NameSearchError.accountNotFound(name)
                }
                guard let serviceURL = web3Name.serviceURLs.first else {
                    throw TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName)
                }

                return self.kiltTransferAssetRecipientRepository.fetchRecipients(url: serviceURL)
            }

        wrapper.addDependency(wrapper: web3NamesWrapper)

        let dependencies = web3NamesWrapper.allOperations + wrapper.dependencies
        return .init(targetOperation: wrapper.targetOperation, dependencies: dependencies)
    }

    private func provideKiltRecipient(
        _ name: String,
        chainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        let slip44Wrapper = fetchSlip44CoinListWrapper()
        let kiltRecipientWrapper = kiltRecipient(by: name, for: chainAsset)

        let mergeOperation = ClosureOperation {
            let slip44CoinList = try slip44Wrapper.extractNoCancellableResultData()
            let kiltRecipients = try kiltRecipientWrapper.targetOperation.extractNoCancellableResultData()
            return try self.handleSearchWeb3Name(
                response: kiltRecipients,
                name: name,
                chainAsset: chainAsset,
                slip44CoinList: slip44CoinList
            )
        }

        let dependencies = [slip44Wrapper] + kiltRecipientWrapper.allOperations
        dependencies.forEach { mergeOperation.addDependency($0) }

        mergeOperation.completionBlock = { [weak self] in
            guard mergeOperation === self?.executingOperation else {
                return
            }
            self?.executingOperation = nil
            do {
                let result = try mergeOperation.extractNoCancellableResultData()
                completionHandler(.success(result))
            } catch let error as TransferSetupWeb3NameSearchError {
                completionHandler(.failure(error))
            } catch {
                completionHandler(.failure(TransferSetupWeb3NameSearchError.kiltService(error)))
            }
        }

        executingOperation = mergeOperation

        operationManager.enqueue(
            operations: dependencies + [mergeOperation],
            in: .transient
        )
    }

    private func handleSearchWeb3Name(
        response: TransferAssetRecipientResponse?,
        name: String,
        chainAsset: ChainAsset,
        slip44CoinList: Slip44CoinList
    ) throws -> [KiltTransferAssetRecipientAccount] {
        let chainName = chainAsset.chain.name

        guard
            let response = response,
            let coin = slip44CoinList.first(where: {
                $0.symbol == chainAsset.asset.symbol
            }),
            let slip44Code = Int(coin.index)
        else {
            throw TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName)
        }

        guard let recipients = response.first(where: {
            $0.key.chainId.match(chainAsset.chain.chainId) && slip44Code == $0.key.slip44Code
        })?.value else {
            throw TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName)
        }

        return recipients
    }

    func search(
        w3nName: String,
        for chainAsset: ChainAsset,
        completionHandler: @escaping (Web3NameSearchResult) -> Void
    ) {
        provideKiltRecipient(w3nName, chainAsset: chainAsset, completionHandler: completionHandler)
    }

    func cancel() {
        clear(cancellable: &executingOperation)
    }
}
