import Foundation
import RobinHood
import SubstrateSdk
import BigInt

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
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
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

        let decodingOperation = StorageKeyDecodingOperation<AssetConversionPallet.PoolAssetPair>(
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

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: [prefixEncodingOperation, keysFetchOperation]
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

extension AssetHubSwapOperationFactory: AssetConversionOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let fetchRemoteWrapper = fetchAllPairsWrapper(dependingOn: codingFactoryOperation)
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

            return .init(args: args, amount: amount)
        }

        mappingOperation.addDependency(quoteOperation)

        let dependencies = [codingFactoryOperation, quoteOperation]

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}
