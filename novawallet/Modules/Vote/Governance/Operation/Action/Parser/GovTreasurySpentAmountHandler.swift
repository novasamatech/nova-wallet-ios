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

        guard path == Treasury.spendCallPath else {
            return nil
        }

        let operation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
            let runtimeContext = context.codingFactory.createRuntimeJsonContext()
            let spentCall = try call.args.map(to: Treasury.SpendCall.self, with: runtimeContext.toRawContext())

            return ReferendumActionLocal.AmountSpendDetails(
                amount: spentCall.amount,
                beneficiary: spentCall.beneficiary
            )
        }

        let wrapper = CompoundOperationWrapper(targetOperation: operation)

        return [wrapper]
    }
}
