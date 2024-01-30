import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class HydraOmnipoolOperationFactory {
    let chain: ChainModel
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    private var quoteStateService: HydraOmnipoolQuoteService?
    private var mutex = NSLock()

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

    private func fetchAllRemoteAssets() -> CompoundOperationWrapper<Set<HydraDx.OmniPoolAssetId>> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let hubAssetIdOperation = PrimitiveConstantOperation<HydraDx.OmniPoolAssetId>.operation(
            for: HydraDx.hubAssetIdPath,
            dependingOn: codingFactoryOperation
        )

        hubAssetIdOperation.addDependency(codingFactoryOperation)

        let keysFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
        let assetsFetchWrapper: CompoundOperationWrapper<[HydraDx.AssetsKey]> = keysFactory.createKeysFetchWrapper(
            by: HydraDx.omnipoolAssets,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        assetsFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<Set<HydraDx.OmniPoolAssetId>> {
            let allAssets = try assetsFetchWrapper.targetOperation.extractNoCancellableResultData()
            let hubAssetId = try hubAssetIdOperation.extractNoCancellableResultData()

            let filteredAssets = allAssets.compactMap { $0.assetId != hubAssetId ? $0.assetId : nil }

            return Set(filteredAssets)
        }

        mapOperation.addDependency(hubAssetIdOperation)
        mapOperation.addDependency(assetsFetchWrapper.targetOperation)

        return assetsFetchWrapper
            .insertingHead(operations: [codingFactoryOperation, hubAssetIdOperation])
            .insertingTail(operation: mapOperation)
    }

    func fetchAllAssets() -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let remoteWrapper = fetchAllRemoteAssets()

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let allLocalAssets = chain.assets.map { ChainAsset(chain: chain, asset: $0) }
        let localAssetsOperation = ClosureOperation<Set<ChainAssetId>> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let localRemoteAssets = try allLocalAssets.reduce(
                into: [HydraDx.OmniPoolAssetId: ChainAssetId]()
            ) { accum, chainAsset in
                let pair = try HydraDxTokenConverter.convertToRemote(
                    chainAsset: chainAsset,
                    codingFactory: codingFactory
                )

                accum[pair.remoteAssetId] = pair.localAssetId
            }

            let remoteAssets = try remoteWrapper.targetOperation.extractNoCancellableResultData()

            return Set(remoteAssets.compactMap { localRemoteAssets[$0] })
        }

        localAssetsOperation.addDependency(codingFactoryOperation)
        localAssetsOperation.addDependency(remoteWrapper.targetOperation)

        return remoteWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: localAssetsOperation)
    }

    private func getTokensPairWrapper(
        for assetIn: ChainAssetId,
        assetOut: ChainAssetId
    ) -> CompoundOperationWrapper<HydraDx.SwapPair> {
        guard let chainAssetIn = chain.asset(for: assetIn.assetId).map({ ChainAsset(chain: chain, asset: $0) }) else {
            return CompoundOperationWrapper.createWithError(
                ChainModelFetchError.noAsset(assetId: assetIn.assetId)
            )
        }

        guard let chainAssetOut = chain.asset(for: assetOut.assetId).map({ ChainAsset(chain: chain, asset: $0) }) else {
            return CompoundOperationWrapper.createWithError(
                ChainModelFetchError.noAsset(assetId: assetOut.assetId)
            )
        }

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let parsingOperation = ClosureOperation<HydraDx.SwapPair> {
            let codingFactory = try coderFactoryOperation.extractNoCancellableResultData()

            let localRemoteIn = try HydraDxTokenConverter.convertToRemote(
                chainAsset: chainAssetIn,
                codingFactory: codingFactory
            )

            let localRemoteOut = try HydraDxTokenConverter.convertToRemote(
                chainAsset: chainAssetOut,
                codingFactory: codingFactory
            )

            return HydraDx.SwapPair(assetIn: localRemoteIn, assetOut: localRemoteOut)
        }

        parsingOperation.addDependency(coderFactoryOperation)

        return CompoundOperationWrapper(targetOperation: parsingOperation, dependencies: [coderFactoryOperation])
    }

    private func getQuoteStateService(for swap: HydraDx.SwapPair) -> HydraOmnipoolQuoteService {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if
            let currentService = quoteStateService,
            currentService.assetIn == swap.assetIn,
            currentService.assetOut == swap.assetOut {
            return currentService
        }

        let newService = HydraOmnipoolQuoteService(
            chain: chain,
            assetIn: swap.assetIn,
            assetOut: swap.assetOut,
            connection: connection,
            runtimeProvider: runtimeService,
            operationQueue: operationQueue,
            workQueue: .global()
        )

        quoteStateService?.throttle()

        quoteStateService = newService
        quoteStateService?.setup()

        return newService
    }

    private func createQuoteStateWrapper(
        dependingOn swapPairOperation: BaseOperation<HydraDx.SwapPair>
    ) -> CompoundOperationWrapper<HydraDx.QuoteRemoteState> {
        OperationCombiningService<HydraDx.QuoteRemoteState>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let swapPair = try swapPairOperation.extractNoCancellableResultData()

            let quoteService = self.getQuoteStateService(for: swapPair)

            let operation = quoteService.createFetchOperation()

            return CompoundOperationWrapper(targetOperation: operation)
        }
    }

    private func createDefaultFeeWrapper() -> CompoundOperationWrapper<HydraDx.FeeEntry> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let assetFeeOperation = StorageConstantOperation<HydraDx.FeeParameters>.operation(
            path: HydraDx.assetFeeParametersPath,
            dependingOn: coderFactoryOperation
        )

        assetFeeOperation.addDependency(coderFactoryOperation)

        let protocolFeeOperation = StorageConstantOperation<HydraDx.FeeParameters>.operation(
            path: HydraDx.protocolFeeParametersPath,
            dependingOn: coderFactoryOperation
        )

        protocolFeeOperation.addDependency(coderFactoryOperation)

        let mergeOperation = ClosureOperation<HydraDx.FeeEntry> {
            let assetFee = try assetFeeOperation.extractNoCancellableResultData().minFee
            let protocolFee = try protocolFeeOperation.extractNoCancellableResultData().minFee

            return HydraDx.FeeEntry(assetFee: assetFee, protocolFee: protocolFee)
        }

        mergeOperation.addDependency(assetFeeOperation)
        mergeOperation.addDependency(protocolFeeOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [coderFactoryOperation, assetFeeOperation, protocolFeeOperation]
        )
    }

    private func calculateSellQuote(
        for args: AssetConversion.QuoteArgs,
        remoteState: HydraDx.QuoteRemoteState,
        defaultFee: HydraDx.FeeEntry
    ) throws -> AssetConversion.Quote {
        guard let assetInState = remoteState.assetInState else {
            throw AssetConversionOperationError.remoteAssetNotFound(args.assetIn)
        }

        guard let assetOutState = remoteState.assetOutState else {
            throw AssetConversionOperationError.remoteAssetNotFound(args.assetOut)
        }

        let assetFee = BigRational.permill(
            of: remoteState.assetOutFee?.assetFee ?? defaultFee.assetFee
        )

        let protocolFee = BigRational.permill(
            of: remoteState.assetInFee?.protocolFee ?? defaultFee.protocolFee
        )

        let inHubReserve = assetInState.hubReserve
        let inReserve = remoteState.assetInBalance ?? 0
        let deltaHubReserveIn = (args.amount * inHubReserve) / (inReserve + args.amount)

        let protocolFeeAmount = protocolFee.mul(value: deltaHubReserveIn)
        let deltaHubReserveOut = deltaHubReserveIn - protocolFeeAmount

        let outReserveHp = remoteState.assetOutBalance ?? 0
        let outHubReserveHp = assetOutState.hubReserve

        let deltaReserveOut = (deltaHubReserveOut * outReserveHp) / (outHubReserveHp + deltaHubReserveOut)

        guard let amountOut = BigUInt(100).sub(rational: assetFee)?.mul(value: deltaReserveOut) else {
            throw AssetConversionOperationError.runtimeError("Fee too big")
        }

        return .init(args: args, amount: amountOut)
    }

    private func calculateBuyQuote(
        for args: AssetConversion.QuoteArgs,
        remoteState: HydraDx.QuoteRemoteState,
        defaultFee: HydraDx.FeeEntry
    ) throws -> AssetConversion.Quote {
        guard let assetInState = remoteState.assetInState else {
            throw AssetConversionOperationError.remoteAssetNotFound(args.assetIn)
        }

        guard let assetOutState = remoteState.assetOutState else {
            throw AssetConversionOperationError.remoteAssetNotFound(args.assetOut)
        }

        let assetFee = BigRational.permill(
            of: remoteState.assetOutFee?.assetFee ?? defaultFee.assetFee
        )

        let protocolFee = BigRational.permill(
            of: remoteState.assetInFee?.protocolFee ?? defaultFee.protocolFee
        )

        let outReserve = remoteState.assetOutBalance ?? 0
        guard let outReserveNoFee = BigUInt(100).sub(rational: assetFee)?.mul(value: outReserve) else {
            throw AssetConversionOperationError.runtimeError("Asset fee too big")
        }

        guard outReserveNoFee > args.amount else {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        let outHubReserve = assetOutState.hubReserve
        let deltaHubReserveOut = (outHubReserve * args.amount) / (outReserveNoFee - args.amount) + 1

        guard protocolFee.denominator > protocolFee.numerator else {
            throw AssetConversionOperationError.runtimeError("Protocol fee too big")
        }

        // deltaHubReserveOut = (1 - protocolFee) * deltaHubReserveIn
        let deltaHubReserveIn = (deltaHubReserveOut * protocolFee.denominator) /
            (protocolFee.denominator - protocolFee.numerator)

        let inReserveHp = remoteState.assetInBalance ?? 0
        let inHubReserveHp = assetInState.hubReserve

        guard inHubReserveHp > deltaHubReserveIn else {
            throw AssetConversionOperationError.quoteCalcFailed
        }

        let amountIn = (inReserveHp * deltaHubReserveIn) / (inHubReserveHp - deltaHubReserveIn) + 1

        return .init(args: args, amount: amountIn)
    }
}

extension HydraOmnipoolOperationFactory: AssetConversionOperationFactoryProtocol {
    func availableDirections() -> CompoundOperationWrapper<[ChainAssetId: Set<ChainAssetId>]> {
        let allAssetsWrapper = fetchAllAssets()

        let mappingOperation = ClosureOperation<[ChainAssetId: Set<ChainAssetId>]> {
            let allAssets = try allAssetsWrapper.targetOperation.extractNoCancellableResultData()

            return allAssets.reduce(into: [ChainAssetId: Set<ChainAssetId>]()) { accum, chainAssetId in
                accum[chainAssetId] = allAssets.subtracting([chainAssetId])
            }
        }

        mappingOperation.addDependency(allAssetsWrapper.targetOperation)

        return allAssetsWrapper.insertingTail(operation: mappingOperation)
    }

    func availableDirectionsForAsset(
        _ chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<Set<ChainAssetId>> {
        let allAssetsWrapper = fetchAllAssets()

        let mappingOperation = ClosureOperation<Set<ChainAssetId>> {
            let allAssets = try allAssetsWrapper.targetOperation.extractNoCancellableResultData()

            guard allAssets.contains(chainAssetId) else {
                return []
            }

            return allAssets.subtracting([chainAssetId])
        }

        mappingOperation.addDependency(allAssetsWrapper.targetOperation)

        return allAssetsWrapper.insertingTail(operation: mappingOperation)
    }

    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let swapPairWrapper = getTokensPairWrapper(for: args.assetIn, assetOut: args.assetOut)
        let quoteStateWrapper = createQuoteStateWrapper(dependingOn: swapPairWrapper.targetOperation)

        quoteStateWrapper.addDependency(operations: [swapPairWrapper.targetOperation])

        let defaultFeeWrapper = createDefaultFeeWrapper()

        let calculateOperation = ClosureOperation<AssetConversion.Quote> {
            let quoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let defaultFee = try defaultFeeWrapper.targetOperation.extractNoCancellableResultData()

            switch args.direction {
            case .sell:
                return try self.calculateSellQuote(
                    for: args,
                    remoteState: quoteState,
                    defaultFee: defaultFee
                )
            case .buy:
                return try self.calculateBuyQuote(
                    for: args,
                    remoteState: quoteState,
                    defaultFee: defaultFee
                )
            }
        }

        calculateOperation.addDependency(defaultFeeWrapper.targetOperation)
        calculateOperation.addDependency(quoteStateWrapper.targetOperation)

        let dependencies = swapPairWrapper.allOperations + quoteStateWrapper.allOperations +
            defaultFeeWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: calculateOperation, dependencies: dependencies)
    }
}
