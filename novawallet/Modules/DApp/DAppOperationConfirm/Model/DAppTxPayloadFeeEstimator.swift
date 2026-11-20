import Foundation
import BigInt
import Operation_iOS
import SubstrateSdk

/**
 *  The node quotes a fee without the tip, and the native estimator adds only the tip
 *  ChargeTransactionPayment carries in a legacy extrinsic. A createTransaction payload brings
 *  the payment extension of the dApp, so the tips the native estimator leaves out are added here:
 *  the one of ChargeAssetTxPayment and any tip of a general transaction. They are read from
 *  the extrinsic built for the estimate, which carries the extension exactly as it will be signed.
 *  The result is in the native token: a fee paid in another asset is converted from it afterwards.
 */
final class DAppTxPayloadFeeEstimator {
    let nativeFeeEstimator: ExtrinsicNativeFeeEstimator

    init(nativeFeeEstimator: ExtrinsicNativeFeeEstimator) {
        self.nativeFeeEstimator = nativeFeeEstimator
    }
}

// MARK: Private

private extension DAppTxPayloadFeeEstimator {
    func findTipLeftOutByNativeEstimator(
        in extrinsicData: Data,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> BigUInt {
        let decoder = try codingFactory.createDecoder(from: extrinsicData)

        let extrinsic: Extrinsic = try decoder.read(
            of: GenericType.extrinsic.name,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )

        switch extrinsic {
        case let .signed(signed):
            let extra = signed.signature.extra
            let totalTip = try DAppTxPayloadPaymentResolver.totalTip(in: extra)

            // the same value ExtrinsicNativeFeeEstimator has already put into its result
            guard let includedTip = extra.getTip() else {
                return totalTip
            }

            guard totalTip >= includedTip else {
                throw ExtrinsicFeeEstimatingError.brokenFee
            }

            return totalTip - includedTip
        case let .generalTransaction(general):
            return try DAppTxPayloadPaymentResolver.totalTip(in: general.explicits)
        case .bare:
            return 0
        }
    }
}

// MARK: ExtrinsicFeeEstimating

extension DAppTxPayloadFeeEstimator: ExtrinsicFeeEstimating {
    func createFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let nativeWrapper = nativeFeeEstimator.createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )

        let mapOperation = ClosureOperation<ExtrinsicFeeEstimationResultProtocol> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let nativeFees = try nativeWrapper.targetOperation.extractNoCancellableResultData().items
            let extrinsics = try extrinsicCreatingResultClosure().extrinsics

            guard nativeFees.count == extrinsics.count else {
                throw ExtrinsicFeeEstimatingError.brokenFee
            }

            let items = try zip(nativeFees, extrinsics).map { nativeFee, extrinsicData in
                let tip = try self.findTipLeftOutByNativeEstimator(in: extrinsicData, codingFactory: codingFactory)

                return ExtrinsicFee(amount: nativeFee.amount + tip, payer: nativeFee.payer, weight: nativeFee.weight)
            }

            return ExtrinsicFeeEstimationResult(items: items)
        }

        mapOperation.addDependency(codingFactoryOperation)
        mapOperation.addDependency(nativeWrapper.targetOperation)

        return nativeWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mapOperation)
    }
}
