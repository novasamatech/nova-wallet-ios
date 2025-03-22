import Foundation

protocol TokenBalanceMinting {
    func getMintCall(
        for accountId: AccountId,
        amount: Balance
    ) -> RuntimeCallCollecting
}
