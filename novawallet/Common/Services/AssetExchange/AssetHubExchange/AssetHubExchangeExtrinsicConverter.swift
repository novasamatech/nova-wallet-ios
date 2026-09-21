import Foundation
import SubstrateSdk

enum AssetHubExchangeBuilderError: Error, Equatable {
    case nonEmptyBuilder
    case batchNotSealed
}

enum AssetHubExchangeExtrinsicConverter {
    static func addingOperation(
        from params: AssetHubExchangeSwapParams,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard let commission = params.commission else {
            return try addingSwap(from: params, builder: builder)
        }

        guard builder.getCalls().isEmpty else {
            throw AssetHubExchangeBuilderError.nonEmptyBuilder
        }

        var currentBuilder = try addingSwap(from: params, builder: builder.with(batchType: .atomic))

        (currentBuilder, _) = try SubstrateTransferCommandFactory().addingTransferCommand(
            to: currentBuilder,
            amount: .concrete(value: commission.amount),
            recipient: commission.beneficiary,
            assetStorageInfo: commission.assetStorageInfo,
            preservingAccount: true
        )

        return try seal(builder: currentBuilder, codingFactory: params.codingFactory)
    }
}

private extension AssetHubExchangeExtrinsicConverter {
    static func addingSwap(
        from params: AssetHubExchangeSwapParams,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        switch params.swap {
        case let .exactIn(call):
            return try builder.adding(call: call.runtimeCall(for: AssetConversionPallet.name))
        case let .exactOut(call):
            return try builder.adding(call: call.runtimeCall(for: AssetConversionPallet.name))
        }
    }

    static func seal(
        builder: ExtrinsicBuilderProtocol,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let sealedBuilder = try builder.batchingCalls(with: codingFactory.metadata)

        let calls = sealedBuilder.getCalls()

        guard
            calls.count == 1,
            let callJson = calls.first,
            try ExtrinsicExtraction.getCall(
                from: callJson,
                context: codingFactory.createRuntimeJsonContext()
            ).path == UtilityPallet.batchAllPath else {
            throw AssetHubExchangeBuilderError.batchNotSealed
        }

        return sealedBuilder
    }
}
