import UIKit
import SubstrateSdk
import BigInt
import Operation_iOS
import Web3Core

final class TokensManageAddInteractor: AnyCancellableCleaning {
    weak var presenter: TokensManageAddInteractorOutputProtocol?

    private var chain: ChainModel
    let connection: JSONRPCEngine
    let queryFactory: EvmQueryContractMessageFactoryProtocol
    let priceIdParser: PriceUrlParserProtocol
    let priceOperationFactory: CoingeckoOperationFactoryProtocol
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    private var pendingQueryIds: [UInt16]?

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        queryFactory: EvmQueryContractMessageFactoryProtocol,
        priceIdParser: PriceUrlParserProtocol,
        priceOperationFactory: CoingeckoOperationFactoryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.connection = connection
        self.queryFactory = queryFactory
        self.priceIdParser = priceIdParser
        self.priceOperationFactory = priceOperationFactory
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    private func handleDetailsResponse(
        _ results: [Result<JSON, Error>],
        contractAddress: AccountAddress
    ) {
        let symbol = EthereumRpcResultParser.parseStringOrNil(from: results[0])
        let decimals = EthereumRpcResultParser.parseUnsignedIntOrNil(from: results[1], bits: 8).map { UInt8($0) }

        let details = EvmContractMetadata(symbol: symbol, decimals: decimals)

        presenter?.didReceiveDetails(details, for: contractAddress)
    }

    private func createPriceIdWrapper(for urlString: String?) -> CompoundOperationWrapper<AssetModel.PriceId?> {
        guard let urlString = urlString, !urlString.isEmpty else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let priceId = priceIdParser.parsePriceId(from: urlString) else {
            return CompoundOperationWrapper.createWithError(TokensManageAddInteractorError.priceIdProcessingFailed)
        }

        let fetchOperation = priceOperationFactory.fetchPriceOperation(
            for: [priceId],
            currency: .usd,
            returnsZeroIfUnsupported: false
        )

        let mapOperation = ClosureOperation<AssetModel.PriceId?> {
            do {
                let prices = try fetchOperation.extractNoCancellableResultData()

                if !prices.isEmpty {
                    return priceId
                } else {
                    throw TokensManageAddInteractorError.priceIdProcessingFailed
                }
            } catch {
                throw TokensManageAddInteractorError.priceIdProcessingFailed
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }

    func createContractExistenseWrapper(
        for address: AccountAddress,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        do {
            let call = try queryFactory.erc20TotalSupply(from: address)
            let params = EvmQueryMessage.Params(call: call, block: .latest)
            let fetchOperation = JSONRPCOperation<EvmQueryMessage.Params, JSON>(
                engine: connection,
                method: EvmQueryMessage.method,
                parameters: params
            )

            let mapOperation = ClosureOperation<Void> {
                if
                    let json = try? fetchOperation.extractNoCancellableResultData(),
                    EthereumRpcResultParser.parseUnsignedIntOrNil(from: .success(json), bits: 256) != nil {
                    return
                }

                throw TokensManageAddInteractorError.contractNotExists(chain: chain)
            }

            mapOperation.addDependency(fetchOperation)

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
        } catch {
            return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }
    }

    private func performTokenSave(newToken: EvmTokenAddRequest, chain: ChainModel) {
        let priceIdWrapper = createPriceIdWrapper(for: newToken.priceIdUrl)

        let contractExistenseWrapper = createContractExistenseWrapper(
            for: newToken.contractAddress,
            chain: chain
        )

        let chainModifyOperation = ClosureOperation<EvmTokenAddResult> {
            try contractExistenseWrapper.targetOperation.extractNoCancellableResultData()

            let priceId = try priceIdWrapper.targetOperation.extractNoCancellableResultData()

            guard let newAsset = AssetModel(request: newToken, priceId: priceId) else {
                throw TokensManageAddInteractorError.tokenSaveFailed(CommonError.dataCorruption)
            }

            let optAsset = chain.assets.first(where: { $0.assetId == newAsset.assetId })

            // a user can't update default assets
            if let asset = optAsset, asset.source == .remote {
                throw TokensManageAddInteractorError.tokenAlreadyExists(asset)
            }

            let newChain = chain.addingOrUpdating(asset: newAsset)

            let chainAsset = ChainAsset(chain: newChain, asset: newAsset)
            let isNew = optAsset == nil

            return EvmTokenAddResult(chainAsset: chainAsset, isNew: isNew)
        }

        chainModifyOperation.addDependency(contractExistenseWrapper.targetOperation)
        chainModifyOperation.addDependency(priceIdWrapper.targetOperation)

        let saveOperation = chainRepository.saveOperation({
            let newChain = try chainModifyOperation.extractNoCancellableResultData().chainAsset.chain

            return [newChain]
        }, {
            []
        })

        saveOperation.addDependency(chainModifyOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try chainModifyOperation.extractNoCancellableResultData()
                    try saveOperation.extractNoCancellableResultData()

                    self?.presenter?.didSaveEvmToken(result)
                } catch {
                    if let interactorError = error as? TokensManageAddInteractorError {
                        self?.presenter?.didReceiveError(interactorError)
                    } else {
                        self?.presenter?.didReceiveError(.tokenSaveFailed(error))
                    }
                }
            }
        }

        let operations = priceIdWrapper.allOperations + contractExistenseWrapper.allOperations +
            [chainModifyOperation, saveOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}

extension TokensManageAddInteractor: TokensManageAddInteractorInputProtocol {
    func provideDetails(for address: AccountAddress) {
        if let pendingQueryIds = pendingQueryIds {
            self.pendingQueryIds = nil
            connection.cancelForIdentifiers(pendingQueryIds)
        }

        let batchId = UUID().uuidString

        do {
            let symbolCall = try queryFactory.erc20Symbol(from: address)
            let decimalsCall = try queryFactory.erc20Decimals(from: address)

            let calls = [symbolCall, decimalsCall]

            for call in calls {
                let params = EvmQueryMessage.Params(call: call, block: .latest)
                try connection.addBatchCallMethod(EvmQueryMessage.method, params: params, batchId: batchId)
            }

            pendingQueryIds = try connection.submitBatch(for: batchId) { [weak self] results in
                DispatchQueue.main.async {
                    guard self?.pendingQueryIds != nil else {
                        return
                    }

                    self?.pendingQueryIds = nil

                    guard calls.count == results.count else {
                        return
                    }

                    self?.handleDetailsResponse(results, contractAddress: address)
                }
            }
        } catch {
            presenter?.didReceiveError(.evmDetailsFetchFailed(error))
        }
    }

    func save(newToken: EvmTokenAddRequest) {
        performTokenSave(newToken: newToken, chain: chain)
    }
}
