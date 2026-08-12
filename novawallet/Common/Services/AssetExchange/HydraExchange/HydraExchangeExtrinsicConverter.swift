import Foundation
import SubstrateSdk

enum HydraExchangeExtrinsicConverter {
    static func addingOperation(
        from params: HydraExchangeSwapParams,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        // The swap and the service commission transfer must succeed or fail together: a partially applied
        // batch would let the swap settle while the commission is skipped, or vice versa.
        var currentBuilder = builder.with(batchType: .atomic)

        if let updateReferralCall = params.updateReferral {
            currentBuilder = try currentBuilder.adding(call: updateReferralCall.runtimeCall())
        }

        switch params.swap {
        case let .omniSell(call):
            currentBuilder = try currentBuilder.adding(call: call.runtimeCall())
        case let .omniBuy(call):
            currentBuilder = try currentBuilder.adding(call: call.runtimeCall())
        case let .routedSell(call):
            currentBuilder = try currentBuilder.adding(call: call.runtimeCall())
        case let .routedBuy(call):
            currentBuilder = try currentBuilder.adding(call: call.runtimeCall())
        }

        if let commission = params.commission {
            // Deliberately not a keep-alive transfer. ORML assets on Hydration are transferred through
            // Currencies/Tokens, whose keep-alive variants either do not exist (Currencies) or would abort
            // the atomic batch on failure and take the user's swap down with it.
            //
            // No error handling here on purpose: call construction cannot fail on a missing call, because
            // the runtime metadata is only consulted later, in ExtrinsicBuilder.build(using:). A throw at
            // this point means a genuine coding error, and failing the fee estimate loudly is the correct
            // response — silently dropping the commission would make the estimate disagree with submission.
            (currentBuilder, _) = try SubstrateTransferCommandFactory().addingTransferCommand(
                to: currentBuilder,
                amount: .concrete(value: commission.amount),
                recipient: commission.beneficiary,
                assetStorageInfo: commission.assetStorageInfo
            )
        }

        return currentBuilder
    }

    static func isOmnipoolSwap(route: HydraDx.RemoteSwapRoute) -> Bool {
        guard route.components.count == 1 else {
            return false
        }

        if case .omnipool = route.components[0].type {
            return true
        } else {
            return false
        }
    }

    static func convertRouteToTrade(_ route: HydraDx.RemoteSwapRoute) -> [HydraRouter.Trade] {
        route.components.map { component in
            switch component.type {
            case .omnipool:
                return HydraRouter.Trade(
                    pool: .omnipool,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case let .stableswap(poolAsset):
                return HydraRouter.Trade(
                    pool: .stableswap(poolAsset),
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case .xyk:
                return HydraRouter.Trade(
                    pool: .xyk,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            case .aave:
                return HydraRouter.Trade(
                    pool: .aave,
                    assetIn: component.assetIn,
                    assetOut: component.assetOut
                )
            }
        }
    }
}
