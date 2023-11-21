import Foundation
import SubstrateSdk
import RobinHood

extension GovSpentAmount {
    final class BatchHandler {
        private func handleInternal(
            call: RuntimeCall<JSON>,
            handlers: [GovSpentAmountHandling],
            context: GovSpentAmount.Context
        ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
            for handler in handlers {
                if
                    let wrappers = try handler.handle(
                        call: call,
                        internalHandlers: handlers,
                        context: context
                    ) {
                    return wrappers
                }
            }

            return nil
        }
    }
}

extension GovSpentAmount.BatchHandler: GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
        let path = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        guard UtilityPallet.isBatch(path: path) else {
            return nil
        }

        let runtimeContext = context.codingFactory.createRuntimeJsonContext()

        let calls = try call.args.map(to: UtilityPallet.Call.self, with: runtimeContext.toRawContext()).calls

        let wrappers = try calls.flatMap { call in
            try handleInternal(call: call, handlers: internalHandlers, context: context) ?? []
        }

        return wrappers
    }
}
