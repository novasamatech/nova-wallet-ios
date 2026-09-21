import Foundation
import Operation_iOS
import SubstrateSdk

struct AssetHubExchangeSwapParams {
    typealias Commission = AssetConversionSwapVerification.Commission

    enum Swap {
        case exactIn(AssetConversionPallet.SwapExactTokensForTokensCall)
        case exactOut(AssetConversionPallet.SwapTokensForExactTokensCall)
    }

    let callArgs: AssetConversion.CallArgs
    let path: [AssetConversionPallet.AssetId]
    let swap: Swap
    let commission: Commission?
    let codingFactory: RuntimeCoderFactoryProtocol

    var verification: AssetConversionSwapVerification {
        .init(
            receiver: callArgs.receiver,
            path: path,
            bounds: .init(swap: swap),
            commission: commission
        )
    }
}

protocol AssetHubExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<AssetHubExchangeSwapParams>
}

final class AssetHubExchangeExtrinsicParamsFactory {
    let chain: ChainModel
    let runtimeProvider: RuntimeCodingServiceProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let recipientFactory: AssetHubExchangeCommissionRecipientFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        runtimeProvider: RuntimeCodingServiceProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        recipientFactory: AssetHubExchangeCommissionRecipientFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.recipientFactory = recipientFactory
        self.operationQueue = operationQueue
    }
}

private extension AssetHubExchangeExtrinsicParamsFactory {
    func createCommission(
        for commission: AssetExchangeCommission,
        args: AssetConversion.CallArgs,
        storageInfo: AssetStorageInfo?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubExchangeSwapParams.Commission {
        guard
            commission.asset == args.assetOut,
            commission.amount > 0,
            commission.amount < args.amountOut,
            commission.beneficiary != args.receiver,
            let storageInfo else {
            throw AssetHubExchangePreparationError.invalidCommission
        }

        let transferPath: CallCodingPath

        switch storageInfo {
        case .native:
            transferPath = .transferKeepAlive
        case let .statemine(info):
            transferPath = PalletAssets.assetsTransferKeepAlive(for: info.palletName)
        case .orml, .ormlHydrationEvm, .erc20, .evmNative, .equilibrium:
            throw AssetHubExchangePreparationError.unsupportedStorage
        }

        for path in [UtilityPallet.batchAllPath, transferPath] where !codingFactory.hasCall(for: path) {
            throw AssetHubExchangePreparationError.runtimeCallUnavailable(path)
        }

        return .init(
            amount: commission.amount,
            beneficiary: commission.beneficiary,
            assetStorageInfo: storageInfo
        )
    }

    func createSwap(
        for args: AssetConversion.CallArgs,
        path: [AssetConversionPallet.AssetId],
        deduction: Balance,
        minimumBalance: Balance
    ) throws -> AssetHubExchangeSwapParams.Swap {
        switch args.direction {
        case .sell:
            let netAmountOut = args.amountOut - deduction
            let netAmountOutMin = netAmountOut - args.slippage.mul(value: netAmountOut)

            guard deduction == 0 || netAmountOutMin >= minimumBalance else {
                throw AssetHubExchangePreparationError.netOutputBelowMinimum
            }

            return .exactIn(
                .init(
                    path: path,
                    amountIn: args.amountIn,
                    amountOutMin: netAmountOutMin + deduction,
                    sendTo: args.receiver,
                    keepAlive: false
                )
            )
        case .buy:
            guard deduction == 0 || args.amountOut - deduction >= minimumBalance else {
                throw AssetHubExchangePreparationError.netOutputBelowMinimum
            }

            return .exactOut(
                .init(
                    path: path,
                    amountOut: args.amountOut,
                    amountInMax: args.amountIn + args.slippage.mul(value: args.amountIn),
                    sendTo: args.receiver,
                    keepAlive: false
                )
            )
        }
    }

    func createParams(
        args: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?,
        storageInfo: AssetStorageInfo?,
        minimumBalance: Balance,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> AssetHubExchangeSwapParams {
        guard
            args.slippage.denominator > 0,
            args.slippage.numerator <= args.slippage.denominator else {
            throw AssetHubExchangePreparationError.invalidSlippage
        }

        guard
            let remoteAssetIn = AssetHubTokensConverter.convertToMultilocation(
                chainAssetId: args.assetIn,
                chain: chain,
                codingFactory: codingFactory
            ) else {
            throw AssetHubExtrinsicConverterError.remoteAssetNotFound(args.assetIn)
        }

        guard
            let remoteAssetOut = AssetHubTokensConverter.convertToMultilocation(
                chainAssetId: args.assetOut,
                chain: chain,
                codingFactory: codingFactory
            ) else {
            throw AssetHubExtrinsicConverterError.remoteAssetNotFound(args.assetOut)
        }

        let preparedCommission = try commission.map {
            try createCommission(
                for: $0,
                args: args,
                storageInfo: storageInfo,
                codingFactory: codingFactory
            )
        }

        let path = [remoteAssetIn, remoteAssetOut]

        let swap = try createSwap(
            for: args,
            path: path,
            deduction: preparedCommission?.amount ?? 0,
            minimumBalance: minimumBalance
        )

        return AssetHubExchangeSwapParams(
            callArgs: args,
            path: path,
            swap: swap,
            commission: preparedCommission,
            codingFactory: codingFactory
        )
    }

    func createUnchargedWrapper(
        for callArgs: AssetConversion.CallArgs
    ) -> CompoundOperationWrapper<AssetHubExchangeSwapParams> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let mappingOperation = ClosureOperation<AssetHubExchangeSwapParams> {
            try self.createParams(
                args: callArgs,
                commission: nil,
                storageInfo: nil,
                minimumBalance: 0,
                codingFactory: codingFactoryOperation.extractNoCancellableResultData()
            )
        }

        mappingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation]
        )
    }
}

extension AssetHubExchangeExtrinsicParamsFactory: AssetHubExchangeExtrinsicParamsFactoryProtocol {
    func createOperationWrapper(
        callArgs: AssetConversion.CallArgs,
        commission: AssetExchangeCommission?
    ) -> CompoundOperationWrapper<AssetHubExchangeSwapParams> {
        guard let commission else {
            return createUnchargedWrapper(for: callArgs)
        }

        guard
            commission.asset == callArgs.assetOut,
            let outputAsset = chain.asset(for: commission.asset.assetId) else {
            return .createWithError(AssetHubExchangePreparationError.invalidCommission)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let storageInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: outputAsset,
            runtimeProvider: runtimeProvider
        )

        let minimumBalanceWrapper: CompoundOperationWrapper<Balance>
        minimumBalanceWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

            return self.recipientFactory.createMinimumBalanceWrapper(
                recipient: commission.beneficiary,
                storageInfo: storageInfo
            )
        }

        minimumBalanceWrapper.addDependency(wrapper: storageInfoWrapper)

        let mappingOperation = ClosureOperation<AssetHubExchangeSwapParams> {
            try self.createParams(
                args: callArgs,
                commission: commission,
                storageInfo: storageInfoWrapper.targetOperation.extractNoCancellableResultData(),
                minimumBalance: minimumBalanceWrapper.targetOperation.extractNoCancellableResultData(),
                codingFactory: codingFactoryOperation.extractNoCancellableResultData()
            )
        }

        mappingOperation.addDependency(codingFactoryOperation)
        mappingOperation.addDependency(storageInfoWrapper.targetOperation)
        mappingOperation.addDependency(minimumBalanceWrapper.targetOperation)

        return minimumBalanceWrapper
            .insertingHead(operations: [codingFactoryOperation] + storageInfoWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}
