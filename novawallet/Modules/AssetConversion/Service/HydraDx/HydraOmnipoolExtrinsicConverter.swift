import Foundation
import SubstrateSdk

enum HydraOmnipoolExtrinsicConverter {
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
        case let .sell(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        case let .buy(call):
            return try currentBuilder.adding(call: call.runtimeCall())
        }
    }
}
