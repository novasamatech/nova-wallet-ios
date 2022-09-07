import Foundation
import RobinHood

protocol ParaStkYieldBoostSubscriptionHandler {
    func handleYieldBoostTasks(
        result: Result<[ParaStkYieldBoostState.Task]?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    )
}

extension ParaStkYieldBoostSubscriptionHandler {
    func handleYieldBoostTasks(
        result _: Result<[ParaStkYieldBoostState.Task]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {}
}
