import Foundation
import RobinHood

protocol AccountAssetBalanceChangeStoreProtocol {
    var chainAssetId: ChainAssetId { get }
    var accountId: AccountId { get }

    func consumeLastBlockHash() -> Data?
}

final class AccountAssetBalanceTrigger: AccountAssetBalanceChangeStoreProtocol {
    weak var delegate: DataProviderTriggerDelegate?

    private(set) var wrappedTrigger: DataProviderTriggerProtocol?
    let eventCenter: EventCenterProtocol
    let chainAssetId: ChainAssetId
    let accountId: AccountId

    private(set) var lastSeenBlockHash: Data?

    init(
        chainAssetId: ChainAssetId,
        eventCenter: EventCenterProtocol,
        wrappedTrigger: DataProviderTriggerProtocol?,
        accountId: AccountId
    ) {
        self.chainAssetId = chainAssetId
        self.accountId = accountId
        self.eventCenter = eventCenter
        self.wrappedTrigger = wrappedTrigger

        self.wrappedTrigger?.delegate = self
        self.eventCenter.add(observer: self)
    }

    func consumeLastBlockHash() -> Data? {
        let hash = lastSeenBlockHash
        lastSeenBlockHash = nil
        return hash
    }
}

extension AccountAssetBalanceTrigger: DataProviderTriggerDelegate {
    func didTrigger() {
        delegate?.didTrigger()
    }
}

extension AccountAssetBalanceTrigger: DataProviderTriggerProtocol {
    func receive(event: DataProviderEvent) {
        wrappedTrigger?.receive(event: event)
    }
}

extension AccountAssetBalanceTrigger: EventVisitorProtocol {
    func processAssetBalanceChanged(event: AssetBalanceChanged) {
        guard
            accountId == event.accountId,
            chainAssetId == event.chainAssetId else {
            return
        }

        lastSeenBlockHash = event.block

        delegate?.didTrigger()
    }
}
