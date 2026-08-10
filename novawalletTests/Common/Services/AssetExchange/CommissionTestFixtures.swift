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
        let storageInfoFactory: MockAssetStorageInfoOperationFactoryProtocol
        let balanceQueryFactory: MockWalletRemoteQueryWrapperFactoryProtocol
    }

    static func createPolicy(
        beneficiaryFree: Balance,
        minBalance: Balance,
        storageInfoResult: Result<AssetStorageInfo, Error> = .success(ormlInfo(existentialDeposit: 1))
    ) -> PolicyUnderTest {
        let storageInfoFactory = MockAssetStorageInfoOperationFactoryProtocol()
            .applyDefault(storageInfoResult: storageInfoResult, minBalance: minBalance)

        let balanceQueryFactory = MockWalletRemoteQueryWrapperFactoryProtocol()
            .applyDefault(free: beneficiaryFree)

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

extension MockAssetStorageInfoOperationFactoryProtocol {
    func applyDefault(
        storageInfoResult: Result<AssetStorageInfo, Error>,
        minBalance: Balance
    ) -> MockAssetStorageInfoOperationFactoryProtocol {
        stub(self) { stub in
            stub.createStorageInfoWrapper(from: any(), runtimeProvider: any()).then { _, _ in
                switch storageInfoResult {
                case let .success(info):
                    return .createWithResult(info)
                case let .failure(error):
                    return .createWithError(error)
                }
            }

            stub.createAssetBalanceExistenceOperation(for: any(), chainId: any(), asset: any()).then { _, _, _ in
                .createWithResult(AssetBalanceExistence(minBalance: minBalance, isSelfSufficient: true))
            }
        }

        return self
    }
}

extension MockWalletRemoteQueryWrapperFactoryProtocol {
    func applyDefault(free: Balance) -> MockWalletRemoteQueryWrapperFactoryProtocol {
        stub(self) { stub in
            stub.queryBalance(for: any(), chainAsset: any()).then { accountId, chainAsset in
                .createWithResult(
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

        return self
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
            commissionPolicy: createPolicy(beneficiaryFree: 10, minBalance: 1).policy,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }
}
