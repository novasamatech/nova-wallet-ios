import Foundation
import SubstrateSdk
import RobinHood
import BigInt

protocol ParaStkScheduledRequestsQueryFactoryProtocol {
    func createOperation(
        for delegator: AccountId,
        collators: [AccountId],
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[ParachainStaking.DelegatorScheduledRequest]>
}

extension ParachainStaking {
    struct DelegatorScheduledRequest: Codable, Equatable {
        let collatorId: AccountId
        let whenExecutable: RoundIndex
        let action: ParachainStaking.DelegationAction

        var unstakingAmount: BigUInt {
            switch action {
            case let .revoke(amount):
                return amount
            case let .decrease(amount):
                return amount
            }
        }

        var isRevoke: Bool {
            switch action {
            case .decrease:
                return false
            case .revoke:
                return true
            }
        }

        init(
            collatorId: AccountId,
            whenExecutable: RoundIndex,
            action: ParachainStaking.DelegationAction
        ) {
            self.collatorId = collatorId
            self.whenExecutable = whenExecutable
            self.action = action
        }

        func isRedeemable(at round: RoundIndex) -> Bool {
            round >= whenExecutable
        }
    }

    final class ScheduledRequestsQueryFactory: ParaStkScheduledRequestsQueryFactoryProtocol {
        let operationQueue: OperationQueue

        init(operationQueue: OperationQueue) {
            self.operationQueue = operationQueue
        }

        func createOperation(
            for delegator: AccountId,
            collators: [AccountId],
            runtimeService: RuntimeCodingServiceProtocol,
            connection: JSONRPCEngine
        ) -> CompoundOperationWrapper<[ParachainStaking.DelegatorScheduledRequest]> {
            let operationManager = OperationManager(operationQueue: operationQueue)

            let queryFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: operationManager
            )

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let queryWrapper: CompoundOperationWrapper<[StorageResponse<[ParachainStaking.ScheduledRequest]>]> =
                queryFactory.queryItems(
                    engine: connection,
                    keyParams: { collators },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: ParachainStaking.delegationRequestsPath
                )

            queryWrapper.addDependency(operations: [codingFactoryOperation])

            let mapOperation = ClosureOperation<[ParachainStaking.DelegatorScheduledRequest]> {
                let responses = try queryWrapper.targetOperation.extractNoCancellableResultData()

                return zip(collators, responses).compactMap { collator, response in
                    guard
                        let delegatorRequest = response.value?.first(
                            where: { $0.delegator == delegator }
                        ) else {
                        return nil
                    }

                    return ParachainStaking.DelegatorScheduledRequest(
                        collatorId: collator,
                        whenExecutable: delegatorRequest.whenExecutable,
                        action: delegatorRequest.action
                    )
                }
            }

            mapOperation.addDependency(queryWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [codingFactoryOperation] + queryWrapper.allOperations
            )
        }
    }
}
