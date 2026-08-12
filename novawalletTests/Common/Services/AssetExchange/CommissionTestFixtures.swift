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

    static func commissionContext(
        storageInfo: AssetStorageInfo?,
        existentialDeposit: Balance = 0
    ) -> HydraExchangeExtrinsicParamsFactory.CommissionContext? {
        storageInfo.map {
            .init(storageInfo: $0, existentialDeposit: existentialDeposit)
        }
    }

    static func makeSwapParams(
        commission: AssetExchangeCommission?,
        storageInfo: AssetStorageInfo?,
        existentialDeposit: Balance = 0,
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
                context: commissionContext(
                    storageInfo: storageInfo,
                    existentialDeposit: existentialDeposit
                ),
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

    static func chain(withOrmlExistentialDeposit deposit: Balance, forAssetId assetId: AssetModel.Id = 1) -> ChainModel {
        let assets = (0 ..< 8).map { index -> AssetModel in
            let id = AssetModel.Id(index)
            let base = ChainModelGenerator.generateAssetWithId(id, assetPresicion: 12)

            guard id == assetId else {
                return base
            }

            return AssetModel(
                assetId: id,
                icon: base.icon,
                name: base.name,
                symbol: base.symbol,
                precision: base.precision,
                priceId: base.priceId,
                stakings: base.stakings,
                type: "orml",
                typeExtras: .dictionaryValue([
                    "currencyIdScale": .stringValue("0x00000000"),
                    "currencyIdType": .stringValue("u32"),
                    "existentialDeposit": .stringValue(String(deposit)),
                    "transfersEnabled": .boolValue(true)
                ]),
                buyProviders: base.buyProviders,
                sellProviders: base.sellProviders,
                enabled: base.enabled,
                source: base.source
            )
        }

        return ChainModelGenerator.generateChain(
            assets: assets,
            defaultChainId: KnowChainId.hydra,
            addressPrefix: 63
        )
    }

    static func createPolicy(
        chainRegistry: ChainRegistryProtocol = MockChainRegistryProtocol().applyDefault(for: [chain])
    ) -> AssetExchangeCommissionPolicy {
        AssetExchangeCommissionPolicy(
            rate: AssetExchangeCommissionConstants.rate,
            beneficiary: beneficiary,
            chainRegistry: chainRegistry
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
