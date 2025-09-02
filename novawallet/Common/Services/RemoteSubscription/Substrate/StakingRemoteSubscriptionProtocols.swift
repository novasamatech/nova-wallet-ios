import Foundation

protocol StakingRemoteSubscriptionServiceProtocol {
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

protocol StakingRemoteAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountData(
        for subscriptionId: UUID,
        chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}
