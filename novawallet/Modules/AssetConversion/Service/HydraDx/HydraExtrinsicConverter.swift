import Foundation
import SubstrateSdk

enum HydraExtrinsicConverter {
    static func addingSetCurrencyCall(
        from params: HydraSwapParams,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard let setCurrencyCall = params.changeFeeCurrency else {
            return builder
        }

        return try builder.adding(call: setCurrencyCall.runtimeCall())
    }

    static func addingOperation(
        from params: HydraSwapParams,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        var currentBuilder = builder

        if let updateReferralCall = params.updateReferral {
            currentBuilder = try currentBuilder.adding(call: updateReferralCall.runtimeCall())
        }

        switch params.swap {
        case let .omniSell(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        case let .omniBuy(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        case let .routedSell(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        case let .routedBuy(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        }
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
            }
        }
    }
}
