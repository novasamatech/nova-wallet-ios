import Foundation
import SubstrateSdk
import Operation_iOS

extension GovSpentAmount {
    final class TreasurySpendLocalHandler {}
}

extension GovSpentAmount.TreasurySpendLocalHandler: GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers _: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
        let path = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let spendPaths = [Treasury.spendLocalCallPath]

        guard spendPaths.contains(path) else {
            return nil
        }

        let operation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
            let runtimeContext = context.codingFactory.createRuntimeJsonContext()

            if
                let spentCall = try? call.args.map(
                    to: Treasury.SpendLocalCall.self,
                    with: runtimeContext.toRawContext()
                ),
                let beneficiary = spentCall.beneficiary.accountId {
                return ReferendumActionLocal.AmountSpendDetails(
                    benefiary: beneficiary,
                    amount: .init(value: spentCall.amount, asset: .current)
                )
            } else {
                return nil
            }
        }

        let wrapper = CompoundOperationWrapper(targetOperation: operation)

        return [wrapper]
    }
}
