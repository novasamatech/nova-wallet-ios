import Foundation
import SubstrateSdk
import RobinHood

extension GovSpentAmount {
    final class TreasurySpentHandler {}
}

extension GovSpentAmount.TreasurySpentHandler: GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers _: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
        let path = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        let spendPaths = [Treasury.spendCallPath, Treasury.spendLocalCallPath]

        guard spendPaths.contains(path) else {
            return nil
        }

        let operation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
            let runtimeContext = context.codingFactory.createRuntimeJsonContext()

            if
                let spentCall = try? call.args.map(
                    to: Treasury.SpendCall.self,
                    with: runtimeContext.toRawContext()
                ) {
                return ReferendumActionLocal.AmountSpendDetails(
                    amount: spentCall.amount,
                    beneficiary: spentCall.beneficiary
                )
            } else {
                return nil
            }
        }

        let wrapper = CompoundOperationWrapper(targetOperation: operation)

        return [wrapper]
    }
}
