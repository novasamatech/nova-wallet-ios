import Foundation
import SubstrateSdk
import RobinHood

extension GovSpentAmount {
    final class TreasuryApproveHandler {}
}

extension GovSpentAmount.TreasuryApproveHandler: GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers _: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
        let path = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

        guard path == Treasury.approveProposalCallPath else {
            return nil
        }

        let runtimeContext = context.codingFactory.createRuntimeJsonContext()
        let approveCall = try call.args.map(
            to: Treasury.ApproveProposal.self,
            with: runtimeContext.toRawContext()
        )

        let keyClosure: () throws -> [StringScaleMapper<Treasury.ProposalIndex>] = {
            [StringScaleMapper(value: approveCall.proposalId)]
        }

        let wrapper: CompoundOperationWrapper<[StorageResponse<Treasury.Proposal>]> = context.requestFactory.queryItems(
            engine: context.connection,
            keyParams: keyClosure,
            factory: { context.codingFactory },
            storagePath: Treasury.proposalsStoragePath
        )

        let mapOperation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
            let responses = try wrapper.targetOperation.extractNoCancellableResultData()
            guard let proposal = responses.first?.value else {
                return nil
            }

            let details = ReferendumActionLocal.AmountSpendDetails(
                amount: proposal.value,
                beneficiary: .accoundId(proposal.beneficiary)
            )

            return details
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let resultWrapper = CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrapper.allOperations
        )

        return [resultWrapper]
    }
}
