import Foundation
import SubstrateSdk
import Operation_iOS

extension GovSpentAmount {
    final class TreasurySpendRemoteHandler {
        let assetConversionFactory: CrosschainAssetConversionFactoryProtocol
        let operationQueue: OperationQueue

        init(
            assetConversionFactory: CrosschainAssetConversionFactoryProtocol,
            operationQueue: OperationQueue
        ) {
            self.assetConversionFactory = assetConversionFactory
            self.operationQueue = operationQueue
        }
    }
}

extension GovSpentAmount.TreasurySpendRemoteHandler: GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers _: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
        let path = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        guard path == Treasury.spendCallPath else {
            return nil
        }

        let wrapper = OperationCombiningService<ReferendumActionLocal.AmountSpendDetails?>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let runtimeContext = context.codingFactory.createRuntimeJsonContext()

            do {
                let spendCall = try call.args.map(
                    to: Treasury.SpendRemoteCall.self,
                    with: runtimeContext.toRawContext()
                )

                guard let beneficiary = spendCall.beneficiary.entity.accountId else {
                    return CompoundOperationWrapper.createWithResult(nil)
                }

                let conversionWrapper = self.assetConversionFactory.createConversionWrapper(
                    from: spendCall.assetKind
                )

                let mappingOperation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
                    guard let asset = try conversionWrapper.targetOperation.extractNoCancellableResultData() else {
                        return nil
                    }

                    return ReferendumActionLocal.AmountSpendDetails(
                        benefiary: beneficiary,
                        amount: .init(value: spendCall.amount, asset: .other(asset))
                    )
                }

                mappingOperation.addDependency(conversionWrapper.targetOperation)

                return conversionWrapper.insertingTail(operation: mappingOperation)
            } catch {
                return CompoundOperationWrapper.createWithResult(nil)
            }
        }

        return [wrapper]
    }
}
