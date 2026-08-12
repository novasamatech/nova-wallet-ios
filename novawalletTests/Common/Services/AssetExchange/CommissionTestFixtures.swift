import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import BigInt
import Cuckoo

enum CommissionTestFixtures {
    static let chain = ChainModelGenerator.generateChain(
        defaultChainId: KnowChainId.hydra,
        generatingAssets: 8,
        addressPrefix: 63
    )

    static func asset(_ id: AssetModel.Id) -> ChainAssetId {
        ChainAssetId(chainId: chain.chainId, assetId: id)
    }

    static func chainAsset(_ id: AssetModel.Id) -> ChainAsset {
        try! chain.chainAssetOrError(for: id)
    }

    static func metaOperation(
        amountIn: Balance,
        amountOut: Balance,
        label: AssetExchangeMetaOperationLabel = .swap
    ) -> AssetExchangeMetaOperationProtocol {
        StubMetaOperation(
            assetIn: chainAsset(0),
            assetOut: chainAsset(1),
            amountIn: amountIn,
            amountOut: amountOut,
            label: label
        )
    }

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

    static func ormlHydrationEvmInfo(module: String = "Currencies") -> AssetStorageInfo {
        .ormlHydrationEvm(
            info: OrmlTokenStorageInfo(
                currencyId: .stringValue("0"),
                currencyData: Data(),
                module: module,
                existentialDeposit: 1,
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
            rateOfGross: rate.asShareOfGross
        )
    }

    static func makeCommission(
        chargingOperationIndex: Int,
        estimatedAmount: Balance
    ) -> AssetExchangeCommission {
        AssetExchangeCommission(
            chargingOperationIndex: chargingOperationIndex,
            asset: ChainAssetId(chainId: KnowChainId.hydra, assetId: 1),
            estimatedAmount: estimatedAmount,
            beneficiary: beneficiary,
            rateOfGross: AssetExchangeCommissionConstants.rate.asShareOfGross
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
        try record(params).addedCalls
    }

    static func record(_ params: HydraExchangeSwapParams) throws -> RecordingExtrinsicBuilder {
        let builder = RecordingExtrinsicBuilder()
        _ = try HydraExchangeExtrinsicConverter.addingOperation(from: params, builder: builder)
        return builder
    }

    static let beneficiary = AccountId(repeating: 1, count: 32)

    final class StubBeneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding {
        let result: Result<Bool, Error>

        init(result: Result<Bool, Error>) {
            self.result = result
        }

        func fetchStateWrapper(
            for chainAsset: ChainAsset
        ) -> CompoundOperationWrapper<CommissionBeneficiaryState> {
            switch result {
            case let .success(canReceive):
                return .createWithResult(
                    CommissionBeneficiaryState(
                        chainAsset: chainAsset,
                        balance: canReceive ? 101 : 100,
                        existentialDeposit: 100
                    )
                )
            case let .failure(error):
                return .createWithError(error)
            }
        }
    }

    static func stubBeneficiaryProvider(canReceive: Bool) -> AssetExchangeCommissionBeneficiaryProviding {
        StubBeneficiaryProvider(result: .success(canReceive))
    }

    static func failingBeneficiaryProvider() -> AssetExchangeCommissionBeneficiaryProviding {
        StubBeneficiaryProvider(result: .failure(CommonError.dataCorruption))
    }

    static func createPolicy(
        chainRegistry: ChainRegistryProtocol = MockChainRegistryProtocol().applyDefault(for: [chain]),
        beneficiaryProvider: AssetExchangeCommissionBeneficiaryProviding = stubBeneficiaryProvider(canReceive: true)
    ) -> AssetExchangeCommissionPolicy {
        AssetExchangeCommissionPolicy(
            rate: AssetExchangeCommissionConstants.rate,
            beneficiary: beneficiary,
            chainRegistry: chainRegistry,
            beneficiaryProvider: beneficiaryProvider
        )
    }

    static func makeBeneficiaryProvider(
        balance: Balance,
        existentialDeposit: Balance,
        chain: ChainModel
    ) -> AssetExchangeCommissionBeneficiaryProvider {
        let balanceFactory = MockWalletRemoteQueryWrapperFactoryProtocol()
        stub(balanceFactory) { stub in
            stub.queryBalance(for: any(), chainAsset: any()).then { _, _ in
                .createWithResult(assetBalance(free: balance, chain: chain))
            }
        }

        return makeBeneficiaryProvider(
            balanceFactory: balanceFactory,
            existentialDeposit: existentialDeposit,
            chain: chain
        )
    }

    static func makeBeneficiaryProvider(
        balanceFactory: MockWalletRemoteQueryWrapperFactoryProtocol,
        existentialDeposit: Balance,
        chain: ChainModel
    ) -> AssetExchangeCommissionBeneficiaryProvider {
        let storageInfoFactory = MockAssetStorageInfoOperationFactoryProtocol()
        stub(storageInfoFactory) { stub in
            stub.createStorageInfoWrapper(from: any(), runtimeProvider: any()).then { _, _ in
                .createWithResult(ormlInfo(existentialDeposit: existentialDeposit))
            }

            stub.createAssetBalanceExistenceOperation(for: any(), chainId: any(), asset: any()).then { _, _, _ in
                .createWithResult(
                    AssetBalanceExistence(minBalance: existentialDeposit, isSelfSufficient: true)
                )
            }
        }

        return AssetExchangeCommissionBeneficiaryProvider(
            beneficiary: beneficiary,
            balanceQueryFactory: balanceFactory,
            assetStorageInfoFactory: storageInfoFactory,
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            operationQueue: OperationQueue()
        )
    }

    static func assetBalance(free: Balance, chain: ChainModel) -> AssetBalance {
        AssetBalance(
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: 1),
            accountId: beneficiary,
            freeInPlank: free,
            reservedInPlank: 0,
            frozenInPlank: 0,
            edCountMode: .basedOnFree,
            transferrableMode: .regular,
            blocked: false
        )
    }
}

extension MockAssetsExchangeGraphProtocol {
    func applyDefault(paths: [AssetExchangeGraphPath]) -> MockAssetsExchangeGraphProtocol {
        stub(self) { stub in
            stub.fetchPaths(from: any(), to: any(), maxTopPaths: any()).thenReturn(paths)
            stub.fetchAssetsIn(given: any()).thenReturn([])
            stub.fetchAssetsOut(given: any()).thenReturn([])
        }

        return self
    }
}

extension CommissionTestFixtures {
    static func makeGraph(paths: [AssetExchangeGraphPath] = []) -> MockAssetsExchangeGraphProtocol {
        MockAssetsExchangeGraphProtocol().applyDefault(paths: paths)
    }

    static func makeFactory() -> AssetsExchangeOperationFactory {
        AssetsExchangeOperationFactory(
            graph: makeGraph(),
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            commissionPolicy: createPolicy(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }
}
