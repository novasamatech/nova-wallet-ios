import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol AssetQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote>
}

protocol AssetHubSwapOperationFactoryProtocol: AssetQuoteFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]>
    func availableDirectionsForAsset(_ chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Set<ChainAssetId>>
    func canPayFee(in chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool>
    func filterCanPayFee(for chainAssets: [ChainAsset]) -> CompoundOperationWrapper<[ChainAsset]>
}

final class AssetHubSwapOperationFactory {
    static let sellQuoteApi = "AssetConversionApi_quote_price_exact_tokens_for_tokens"
    static let buyQuoteApi = "AssetConversionApi_quote_price_exact_tokens_for_tokens"

    let chain: ChainModel
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationQueue = operationQueue
    }

    private func fetchAllPairsWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AssetConversionPallet.PoolAssetPair]> {
        let prefixEncodingOperation = UnkeyedEncodingOperation(
            path: AssetConversionPallet.poolsPath,
            storageKeyFactory: StorageKeyFactory()
        )

        prefixEncodingOperation.configurationBlock = {
            do {
                prefixEncodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                prefixEncodingOperation.result = .failure(error)
            }
        }

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            prefixKeyClosure: { try prefixEncodingOperation.extractNoCancellableResultData() },
            mapper: AnyMapper(mapper: IdentityMapper())
        ).longrunOperation()

        keysFetchOperation.addDependency(prefixEncodingOperation)

        let decodingOperation = StorageKeyDecodingOperation<AssetConversionPallet.AssetIdPair>(
            path: AssetConversionPallet.poolsPath
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                decodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(keysFetchOperation)

        let mappingOperation = ClosureOperation<[AssetConversionPallet.PoolAssetPair]> {
            let decodedPairs = try decodingOperation.extractNoCancellableResultData()

            return decodedPairs.map { assetIdPair in
                let asset1 = AssetHubTokensConverter.convertFromMultilocation(
                    assetIdPair.asset1,
                    chain: chain
                )

                let asset2 = AssetHubTokensConverter.convertFromMultilocation(
                    assetIdPair.asset2,
                    chain: chain
                )

                return .init(asset1: asset1, asset2: asset2)
            }
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [prefixEncodingOperation, keysFetchOperation, decodingOperation]
        )
    }

    private func mapRemotePairsOperation(
        for chain: ChainModel,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        remotePairsOperation: BaseOperation<[AssetConversionPallet.PoolAssetPair]>
    ) -> BaseOperation<[ChainAssetId: Set<ChainAssetId>]> {
        ClosureOperation<[ChainAssetId: Set<ChainAssetId>]> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let remotePairs = try remotePairsOperation.extractNoCancellableResultData()

            let optNativeAsset = chain.utilityAsset()

            let initAssetsStore = [JSON: (AssetModel, AssetsPalletStorageInfo)]()
            let assetsPalletTokens = chain.assets.reduce(into: initAssetsStore) { store, asset in
                let optStorageInfo = try? AssetStorageInfo.extract(from: asset, codingFactory: codingFactory)
                guard case let .statemine(info) = optStorageInfo else {
                    return
                }

                store[info.assetId] = (asset, info)
            }

            let mappingClosure: (AssetConversionPallet.PoolAsset) -> ChainAssetId? = { remoteAsset in
                switch remoteAsset {
                case .native:
                    if let nativeAsset = optNativeAsset {
                        return ChainAssetId(chainId: chain.chainId, assetId: nativeAsset.assetId)
                    } else {
                        return nil
                    }
                case let .assets(pallet, index):
                    guard let localToken = assetsPalletTokens[.stringValue(String(index))] else {
                        return nil
                    }

                    let palletName = localToken.1.palletName ?? PalletAssets.name

                    guard
                        let moduleIndex = codingFactory.metadata.getModuleIndex(palletName),
                        moduleIndex == pallet else {
                        // only Assets pallet currently supported
                        return nil
                    }

                    return ChainAssetId(chainId: chain.chainId, assetId: localToken.0.assetId)
                case let .foreign(remoteId):
                    guard
                        let json = try? remoteId.toScaleCompatibleJSON(),
                        let localToken = assetsPalletTokens[json] else {
                        return nil
                    }

                    return ChainAssetId(chainId: chain.chainId, assetId: localToken.0.assetId)
                default:
                    return nil
                }
            }

            let initPairsStore = [ChainAssetId: Set<ChainAssetId>]()
            let result = remotePairs.reduce(into: initPairsStore) { store, remotePair in
                guard
                    let asset1 = mappingClosure(remotePair.asset1),
                    let asset2 = mappingClosure(remotePair.asset2) else {
                    return
                }

                store[asset1] = Set([asset2]).union(store[asset1] ?? [])
                store[asset2] = Set([asset1]).union(store[asset2] ?? [])
            }

            return result
        }
    }
}

extension AssetHubSwapOperationFactory: AssetHubSwapOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let fetchRemoteWrapper = fetchAllPairsWrapper(dependingOn: codingFactoryOperation, chain: chain)
        let mappingOperation = mapRemotePairsOperation(
            for: chain,
            dependingOn: codingFactoryOperation,
            remotePairsOperation: fetchRemoteWrapper.targetOperation
        )

        fetchRemoteWrapper.addDependency(operations: [codingFactoryOperation])
        mappingOperation.addDependency(fetchRemoteWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + fetchRemoteWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func availableDirectionsForAsset(_ chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let allDirectionsWrapper = availableDirections()

        let mappingOperation = ClosureOperation<Set<ChainAssetId>> {
            let allChainAssets = try allDirectionsWrapper.targetOperation.extractNoCancellableResultData()

            return allChainAssets[chainAssetId] ?? []
        }

        mappingOperation.addDependency(allDirectionsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: allDirectionsWrapper.allOperations
        )
    }

    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let request = AssetHubSwapRequestBuilder(chain: chain).build(args: args) {
            try codingFactoryOperation.extractNoCancellableResultData()
        }

        let quoteOperation = JSONRPCOperation<StateCallRpc.Request, String>(
            engine: connection,
            method: StateCallRpc.method
        )

        quoteOperation.parameters = request

        quoteOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<AssetConversion.Quote> {
            let responseString = try quoteOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let amount = try AssetHubSwapRequestSerializer.deserialize(
                quoteResponse: responseString,
                codingFactory: codingFactory
            )

            return .init(args: args, amount: amount, context: nil)
        }

        mappingOperation.addDependency(quoteOperation)

        let dependencies = [codingFactoryOperation, quoteOperation]

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func canPayFee(in chainAssetId: ChainAssetId) -> CompoundOperationWrapper<Bool> {
        guard let utilityAssetId = chain.utilityChainAssetId() else {
            return CompoundOperationWrapper.createWithResult(false)
        }

        if chainAssetId == utilityAssetId {
            return CompoundOperationWrapper.createWithResult(true)
        }

        let availableDirectionsWrapper = availableDirectionsForAsset(chainAssetId)

        let mergeOperation = ClosureOperation<Bool> {
            let directions = try availableDirectionsWrapper.targetOperation.extractNoCancellableResultData()

            return directions.contains(utilityAssetId)
        }

        mergeOperation.addDependency(availableDirectionsWrapper.targetOperation)

        return availableDirectionsWrapper.insertingTail(operation: mergeOperation)
    }

    func filterCanPayFee(for chainAssets: [ChainAsset]) -> CompoundOperationWrapper<[ChainAsset]> {
        guard let utilityAssetId = chain.utilityChainAssetId() else {
            return CompoundOperationWrapper.createWithResult([])
        }

        let availableDirectionsWrapper = availableDirections()

        let filterOperation = ClosureOperation<[ChainAsset]> {
            let availableDirections = try availableDirectionsWrapper.targetOperation.extractNoCancellableResultData()

            let canPayFeeAssets = chainAssets.filter { chainAsset in
                guard chainAsset.chainAssetId != utilityAssetId else { return true }

                return availableDirections[chainAsset.chainAssetId]?.contains(utilityAssetId) ?? false
            }

            return canPayFeeAssets
        }

        filterOperation.addDependency(availableDirectionsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: availableDirectionsWrapper.allOperations
        )
    }
}
