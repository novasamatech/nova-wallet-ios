import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt
import Cuckoo

enum CommissionTestFixtures {
    // `addressPrefix` is `ChainModel.AddressPrefix`, a typealias for `UInt64`
    // (`ChainModel.swift:10`), so the integer literal binds without a conversion.
    static let chain = ChainModelGenerator.generateChain(
        defaultChainId: KnowChainId.hydra,
        generatingAssets: 8,
        addressPrefix: 63
    )

    static func asset(_ id: AssetModel.Id) -> ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: id)
    }

    /// Path whose i-th edge has the given type and connects asset i to asset i+1.
    static func createPath(_ types: [AssetExchangeEdgeType]) -> AssetExchangeGraphPath {
        types.enumerated().map { index, type in
            AnyAssetExchangeEdge(
                StubAssetExchangeEdge(
                    origin: asset(AssetModel.Id(index)),
                    destination: asset(AssetModel.Id(index + 1)),
                    type: type,
                    chain: chain
                )
            )
        }
    }

    /// Route over `createPath(types)`. `amounts` gives each item's quote in path order, so
    /// `items[i].amountOut(for: .sell)` is `amounts[i]`. Precondition: counts are equal.
    static func createRoute(
        _ types: [AssetExchangeEdgeType],
        amounts: [Balance],
        direction: AssetConversion.Direction = .sell
    ) -> AssetExchangeRoute {
        let items = zip(createPath(types), amounts).map { edge, amount in
            AssetExchangeRouteItem(edge: edge, amount: amount, quote: amount)
        }

        return AssetExchangeRoute(items: items, amount: amounts.first ?? 0, direction: direction)
    }

    /// Every item carries the same amount.
    static func createRoute(
        _ types: [AssetExchangeEdgeType],
        amount: Balance,
        direction: AssetConversion.Direction = .sell
    ) -> AssetExchangeRoute {
        createRoute(types, amounts: Array(repeating: amount, count: types.count), direction: direction)
    }

    static func ormlInfo(existentialDeposit: Balance) -> AssetStorageInfo {
        .orml(
            info: OrmlTokenStorageInfo(
                currencyId: .stringValue("0"),
                currencyData: Data(),
                module: "Tokens",
                existentialDeposit: existentialDeposit,
                canTransferAll: true
            )
        )
    }

    static func ormlInfo(module: String) -> AssetStorageInfo {
        .orml(
            info: OrmlTokenStorageInfo(
                currencyId: .stringValue("0"),
                currencyData: Data(),
                module: module,
                existentialDeposit: 1,
                canTransferAll: true
            )
        )
    }

    static func nativeInfo() -> AssetStorageInfo {
        .native(info: NativeTokenStorageInfo(canTransferAll: true, transferCallPath: .transferAllowDeath))
    }

    static func makeCallArgs(
        direction: AssetConversion.Direction,
        amountIn: Balance,
        amountOut: Balance,
        slippage: BigRational
    ) -> AssetConversion.CallArgs {
        AssetConversion.CallArgs(
            assetIn: ChainAssetId(chainId: KnowChainId.hydra, assetId: 0),
            amountIn: amountIn,
            assetOut: ChainAssetId(chainId: KnowChainId.hydra, assetId: 1),
            amountOut: amountOut,
            receiver: Data(repeating: 2, count: 32),
            direction: direction,
            slippage: slippage
        )
    }

    static func makeCommission(rate: BigRational = AssetExchangeCommissionConstants.rate) -> AssetExchangeCommission {
        AssetExchangeCommission(
            chargingOperationIndex: 0,
            asset: ChainAssetId(chainId: KnowChainId.hydra, assetId: 1),
            estimatedAmount: 999_999_999,
            beneficiary: Data(repeating: 3, count: 32),
            rate: rate
        )
    }

    static func makeSwapParams(
        commission: AssetExchangeCommission?,
        storageInfo: AssetStorageInfo?,
        callArgs: AssetConversion.CallArgs
    ) -> HydraExchangeSwapParams {
        HydraExchangeSwapParams(
            params: .init(referral: Data(repeating: 9, count: 32)),
            updateReferral: nil,
            swap: .omniSell(
                HydraOmnipool.SellCall(
                    assetIn: 0,
                    assetOut: 1,
                    amount: callArgs.amountIn,
                    minBuyAmount: callArgs.amountOut
                )
            ),
            commission: HydraExchangeExtrinsicParamsFactory.commissionParams(
                for: commission,
                storageInfo: storageInfo,
                callArgs: callArgs
            )
        )
    }

    static func makeRecordedCalls(_ params: HydraExchangeSwapParams) throws -> [CallCodingPath] {
        let builder = RecordingExtrinsicBuilder()
        _ = try HydraExchangeExtrinsicConverter.addingOperation(from: params, builder: builder)
        return builder.addedCalls
    }

    static let beneficiary = AccountId(repeating: 1, count: 32)

    struct PolicyUnderTest {
        let policy: AssetExchangeCommissionPolicy
        let storageInfoFactory: CountingAssetStorageInfoFactory
        let balanceQueryFactory: CountingBalanceQueryFactory
    }

    /// The stubs are returned alongside the policy because three rows assert on their counters,
    /// and the policy stores them behind protocol types.
    static func createPolicy(
        beneficiaryFree: Balance,
        minBalance: Balance,
        storageInfoResult: Result<AssetStorageInfo, Error> = .success(ormlInfo(existentialDeposit: 1))
    ) -> PolicyUnderTest {
        let storageInfoFactory = CountingAssetStorageInfoFactory(
            storageInfoResult: storageInfoResult,
            minBalance: minBalance
        )

        let balanceQueryFactory = CountingBalanceQueryFactory(free: beneficiaryFree)

        let policy = AssetExchangeCommissionPolicy(
            rate: AssetExchangeCommissionConstants.rate,
            beneficiary: beneficiary,
            assetStorageInfoFactory: storageInfoFactory,
            balanceQueryFactory: balanceQueryFactory,
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            operationQueue: OperationQueue()
        )

        return PolicyUnderTest(
            policy: policy,
            storageInfoFactory: storageInfoFactory,
            balanceQueryFactory: balanceQueryFactory
        )
    }
}

final class CountingAssetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol {
    let storageInfoResult: Result<AssetStorageInfo, Error>
    let minBalance: Balance

    private(set) var storageInfoCallCount = 0
    private(set) var depositCallCount = 0

    init(storageInfoResult: Result<AssetStorageInfo, Error>, minBalance: Balance) {
        self.storageInfoResult = storageInfoResult
        self.minBalance = minBalance
    }

    func createStorageInfoWrapper(
        from _: AssetModel,
        runtimeProvider _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AssetStorageInfo> {
        storageInfoCallCount += 1

        switch storageInfoResult {
        case let .success(info):
            return .createWithResult(info)
        case let .failure(error):
            return .createWithError(error)
        }
    }

    func createAssetBalanceExistenceOperation(
        for _: AssetStorageInfo,
        chainId _: ChainModel.Id,
        asset _: AssetModel
    ) -> CompoundOperationWrapper<AssetBalanceExistence> {
        depositCallCount += 1

        return .createWithResult(AssetBalanceExistence(minBalance: minBalance, isSelfSufficient: true))
    }
}

final class CountingBalanceQueryFactory: WalletRemoteQueryWrapperFactoryProtocol {
    let free: Balance

    private(set) var callCount = 0
    private(set) var requestedAccountIds: [AccountId] = []

    init(free: Balance) {
        self.free = free
    }

    func queryBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<AssetBalance> {
        callCount += 1
        requestedAccountIds.append(accountId)

        return .createWithResult(
            AssetBalance(
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId,
                freeInPlank: free,
                reservedInPlank: 0,
                frozenInPlank: 0,
                edCountMode: .basedOnFree,
                transferrableMode: .regular,
                blocked: false
            )
        )
    }
}

final class StubExchangePathCostEstimator: AssetsExchangePathCostEstimating {
    func costEstimationWrapper(
        for _: AssetExchangeGraphPath
    ) -> CompoundOperationWrapper<AssetsExchangePathCost> {
        CompoundOperationWrapper.createWithResult(.zero)
    }
}

final class StubExchangeGraph: AssetsExchangeGraphProtocol {
    let paths: [AssetExchangeGraphPath]

    init(paths: [AssetExchangeGraphPath]) {
        self.paths = paths
    }

    func fetchPaths(
        from _: ChainAssetId,
        to _: ChainAssetId,
        maxTopPaths _: Int
    ) -> [AssetExchangeGraphPath] {
        paths
    }

    func fetchReachability() -> AssetsExchageGraphReachabilityProtocol {
        fatalError("unused")
    }

    func fetchAssetsIn(given _: ChainAssetId?) -> Set<ChainAssetId> {
        []
    }

    func fetchAssetsOut(given _: ChainAssetId?) -> Set<ChainAssetId> {
        []
    }
}

final class HydraExchangeHostStub: HydraExchangeHostProtocol {
    var chain: ChainModel { CommissionTestFixtures.chain }
    var operationQueue: OperationQueue { OperationQueue() }
    var logger: LoggerProtocol { Logger.shared }

    var selectedAccount: ChainAccountResponse { fatalError("unused") }
    var submissionMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol { fatalError("unused") }
    var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol { fatalError("unused") }
    var extrinsicParamsFactory: HydraExchangeExtrinsicParamsFactoryProtocol { fatalError("unused") }
    var signingWrapper: SigningWrapperProtocol { fatalError("unused") }
    var runtimeService: RuntimeProviderProtocol { fatalError("unused") }
    var connection: JSONRPCEngine { fatalError("unused") }
    var executionTimeEstimator: AssetExchangeTimeEstimating { fatalError("unused") }
}

extension CommissionTestFixtures {
    static func makeFactory() -> AssetsExchangeOperationFactory {
        AssetsExchangeOperationFactory(
            graph: StubExchangeGraph(paths: []),
            pathCostEstimator: StubExchangePathCostEstimator(),
            commissionPolicy: createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    static func makeHydraEdges() -> [any AssetExchangableGraphEdge] {
        let account = AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.hydra)
        let connection = TestJSONRPCEngine()
        let runtimeProvider = MockRuntimeProviderProtocol().applyDefault(for: chain.chainId)
        let queue = OperationQueue()
        let host = HydraExchangeHostStub()
        let pair = HydraDx.RemoteSwapPair(assetIn: 0, assetOut: 1)

        return [
            HydraOmnipoolExchangeEdge(
                origin: asset(0),
                destination: asset(1),
                remoteSwapPair: pair,
                host: host,
                quoteFactory: HydraOmnipoolQuoteFactory(
                    flowState: HydraOmnipoolFlowState(
                        account: account,
                        chain: chain,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        notificationsRegistrar: nil,
                        operationQueue: queue,
                        logger: Logger.shared
                    )
                )
            ),
            HydraStableswapExchangeEdge(
                origin: asset(0),
                destination: asset(1),
                remoteSwapPair: pair,
                poolAsset: 0,
                host: host,
                quoteFactory: HydraStableswapQuoteFactory(
                    flowState: HydraStableswapFlowState(
                        account: account,
                        chain: chain,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        notificationsRegistrar: nil,
                        operationQueue: queue
                    )
                )
            ),
            AssetsHydraXYKExchangeEdge(
                origin: asset(0),
                destination: asset(1),
                remoteSwapPair: pair,
                host: host,
                quoteFactory: HydraXYKSwapQuoteFactory(
                    flowState: HydraXYKFlowState(
                        account: account,
                        chain: chain,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        notificationsRegistrar: nil,
                        operationQueue: queue,
                        logger: Logger.shared
                    )
                )
            ),
            HydraAaveExchangeEdge(
                origin: asset(0),
                destination: asset(1),
                remoteSwapPair: pair,
                host: host,
                quoteFactory: HydraAaveSwapQuoteFactory(
                    flowState: HydraAaveFlowState(
                        account: account,
                        connection: connection,
                        runtimeProvider: runtimeProvider,
                        notificationsRegistrar: nil,
                        operationQueue: queue,
                        logger: Logger.shared
                    )
                )
            )
        ]
    }
}
