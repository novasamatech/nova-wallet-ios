import UIKit
import SubstrateSdk
import BigInt
import RobinHood

final class TokensManageAddInteractor: AnyCancellableCleaning {
    weak var presenter: TokensManageAddInteractorOutputProtocol?

    private var chain: ChainModel
    let connection: JSONRPCEngine
    let queryFactory: EvmQueryContractMessageFactoryProtocol
    let priceIdParser: PriceUrlParserProtocol
    let priceOperationFactory: CoingeckoOperationFactoryProtocol
    let chainRepository: AnyDataProviderRepository<ChainModel>
    let operationQueue: OperationQueue

    private var pendingQueryId: UInt16?
    private var priceIdCancellable: CancellableCall?

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
        let hexSymbol = (try? results[0].get())?.stringValue
        let symbol: String? = hexSymbol.flatMap { hexString in
            guard let data = try? Data(hexString: hexString) else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }

        let decimals: UInt8?

        if let decimalsString = (try? results[1].get())?.stringValue {
            decimals = BigUInt.fromHexString(decimalsString).map { UInt8($0) }
        } else {
            decimals = nil
        }

        let details = EvmContractMetadata(symbol: symbol, decimals: decimals)

        presenter?.didReceiveDetails(details, for: contractAddress)
    }
}

extension TokensManageAddInteractor: TokensManageAddInteractorInputProtocol {
    func provideDetails(for address: AccountAddress) {
        if let pendingQueryId = pendingQueryId {
            self.pendingQueryId = nil
            connection.cancelForIdentifier(pendingQueryId)
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

            pendingQueryId = try connection.submitBatch(for: batchId) { [weak self] results in
                DispatchQueue.main.async {
                    guard self?.pendingQueryId != nil else {
                        return
                    }

                    self?.pendingQueryId = nil

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

    func processPriceId(from urlString: String) {
        if priceIdCancellable != nil {
            clear(cancellable: &priceIdCancellable)
        }

        guard let priceId = priceIdParser.parsePriceId(from: urlString) else {
            presenter?.didReceiveError(.priceIdProcessingFailed)
            return
        }

        let operation = priceOperationFactory.fetchPriceOperation(for: [priceId], currency: .usd)
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard operation === self?.priceIdCancellable else {
                    return
                }

                self?.priceIdCancellable = nil

                do {
                    let prices = try operation.extractNoCancellableResultData()

                    if !prices.isEmpty {
                        self?.presenter?.didExtractPriceId(priceId, from: urlString)
                    } else {
                        self?.presenter?.didReceiveError(.priceIdProcessingFailed)
                    }
                } catch {
                    self?.presenter?.didReceiveError(.priceIdProcessingFailed)
                }
            }
        }

        priceIdCancellable = operation

        operationQueue.addOperation(operation)
    }

    func save(newToken: EvmTokenAddRequest) {
        guard
            let newAsset = AssetModel(request: newToken),
            chain.assets.contains(where: { $0.assetId == newAsset.assetId }) else {
            presenter?.didReceiveError(.tokenAlreadyExists)
            return
        }

        let newChain = chain.adding(asset: newAsset)

        let saveOperation = chainRepository.saveOperation({
            [newChain]
        }, {
            []
        })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    try saveOperation.extractNoCancellableResultData()

                    self?.chain = newChain
                    self?.presenter?.didSaveEvmToken(newAsset)
                } catch {
                    self?.presenter?.didReceiveError(.tokenSaveFailed(error))
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}
