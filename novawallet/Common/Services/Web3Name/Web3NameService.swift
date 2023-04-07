import RobinHood
import SubstrateSdk
import Foundation

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
                guard let serviceId = web3Name.serviceId,
                      let serviceURL = web3Name.serviceURLs.first else {
                    throw Web3NameServiceError.serviceNotFound(name, chainName)
                }
                return self.kiltTransferAssetRecipientRepository.fetchRecipients(
                    url: serviceURL,
                    hash: serviceId
                )
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
                return .kiltService(error)
            }
        }
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

    private func tokenMatcher(
        _ assetId: Caip19.AssetId,
        slip44CoinCode: Int?,
        evmContractAddress: String?
    ) -> Bool {
        switch assetId.knownToken {
        case let .slip44(coin):
            return slip44CoinCode == coin
        case let .erc20(contract):
            return evmContractAddress == contract
        default:
            return false
        }
    }

    private func handleSearchWeb3NameResult(
        response: TransferAssetRecipientResponse?,
        name: String,
        chainAsset: ChainAsset,
        originAsset _: AssetModel,
        slip44CoinList: Slip44CoinList
    ) throws -> [Web3NameTransferAssetRecipientAccount] {
        let chain = chainAsset.chain

        guard let response = response else {
            throw Web3NameServiceError.serviceNotFound(name, chain.name)
        }

        let evmContractAddress = chainAsset.asset.evmContractAddress
        let coin = slip44CoinList.first(where: {
            $0.symbol == chainAsset.asset.symbol
        }).map { Int($0.index) } ?? nil

        if evmContractAddress == nil, coin == nil {
            throw Web3NameServiceError.tokenNotFound(token: chainAsset.asset.symbol)
        }

        guard let recipients = response.first(where: {
            $0.key.chainId.match(chain.chainId) && tokenMatcher(
                $0.key,
                slip44CoinCode: coin,
                evmContractAddress: evmContractAddress
            )
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
