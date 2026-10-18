import Foundation
import SubstrateSdk

struct SubtensorEventMatcher: ExtrinsicEventsMatching {
    static let matchedEvents: Set<EventCodingPath> = [
        SubtensorPallet.stakeAddedEventPath,
        SubtensorPallet.stakeRemovedEventPath,
        SubtensorPallet.basketClaimedEventPath,
        SubtensorPallet.rootClaimedEventPath,
        SubtensorPallet.transactionFeePaidWithAlphaEventPath,
        TransactionPaymentPallet.feePaidPath,
        BalancesPallet.balancesTransfer
    ]

    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, oneOf: Self.matchedEvents)
    }
}

extension SubtensorPallet {
    static var transactionFeePaidWithAlphaEventPath: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "TransactionFeePaidWithAlpha")
    }

    struct TransactionFeePaidWithAlphaEvent: Decodable {
        let who: AccountId
        let netuid: UInt16
        let alphaFee: Balance
        let taoAmount: Balance

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            who = try container.decode(BytesCodable.self).wrappedValue
            netuid = try container.decode(StringScaleMapper<UInt16>.self).value
            alphaFee = try container.decode(StringScaleMapper<Balance>.self).value
            taoAmount = try container.decode(StringScaleMapper<Balance>.self).value
        }
    }
}

struct SubtensorOutcomeParser {
    let coldkey: AccountId
    let novaFeeBeneficiary: AccountId?
    let codingFactory: RuntimeCoderFactoryProtocol

    func parse(
        events: [Event],
        for operation: SubtensorOperation,
        extrinsicHash: ExtrinsicHash,
        blockHash: BlockHash
    ) -> SubtensorOperationOutcome {
        let context = codingFactory.createRuntimeJsonContext().toRawContext()
        let decodedEvents = events.compactMap { decode(event: $0, context: context) }

        let target = SubtensorOutcomeTarget(operation: operation, coldkey: coldkey)
        let alphaFee = decodedEvents.lazy.compactMap { $0.alphaFeePaid(by: coldkey) }.first

        return SubtensorOperationOutcome(
            executed: executedAmounts(in: decodedEvents, target: target, alphaFee: alphaFee),
            novaFeePaid: novaFeePaid(in: decodedEvents),
            alphaFeePaid: alphaFee?.alphaFee,
            networkFeePaid: alphaFee?.taoAmount ?? transactionFeePaid(in: decodedEvents),
            extrinsicHash: extrinsicHash,
            blockHash: blockHash
        )
    }
}

private extension SubtensorOutcomeParser {
    func decode(event: Event, context: [CodingUserInfoKey: Any]) -> SubtensorDecodedEvent? {
        let metadata = codingFactory.metadata

        typealias Decoded = SubtensorDecodedEvent

        func matched<T: Decodable>(_ path: EventCodingPath, _ wrap: (T) -> Decoded) -> Decoded? {
            guard metadata.eventMatches(event, path: path) else {
                return nil
            }

            return (try? event.params.map(to: T.self, with: context)).map(wrap)
        }

        return matched(SubtensorPallet.stakeAddedEventPath, Decoded.stakeAdded) ??
            matched(SubtensorPallet.stakeRemovedEventPath, Decoded.stakeRemoved) ??
            matched(SubtensorPallet.basketClaimedEventPath, Decoded.basketClaimed) ??
            matched(SubtensorPallet.rootClaimedEventPath, Decoded.rootClaimed) ??
            matched(SubtensorPallet.transactionFeePaidWithAlphaEventPath, Decoded.alphaFeePaid) ??
            matched(TransactionPaymentPallet.feePaidPath, Decoded.transactionFeePaid) ??
            matched(BalancesPallet.balancesTransfer, Decoded.transfer)
    }

    func executedAmounts(
        in decodedEvents: [SubtensorDecodedEvent],
        target: SubtensorOutcomeTarget,
        alphaFee: SubtensorPallet.TransactionFeePaidWithAlphaEvent?
    ) -> SubtensorExecutedAmounts? {
        let changes: [SubtensorStakeChange]

        switch target.kind {
        case .stake:
            changes = decodedEvents.compactMap { $0.stakeAdded(matching: target) }
        case .unstake:
            let feeSaleIndex = alphaFee.flatMap { fee in
                decodedEvents.firstIndex { $0.isStakeRemoved(by: target.coldkey, netuid: fee.netuid) }
            }

            changes = decodedEvents.enumerated().compactMap { index, event in
                index == feeSaleIndex ? nil : event.stakeRemoved(matching: target)
            }
        case .claim:
            return claimedAmounts(in: decodedEvents, target: target)
        }

        guard !changes.isEmpty else {
            return nil
        }

        return SubtensorExecutedAmounts(
            tao: changes.reduce(Balance(0)) { $0 + $1.tao },
            alpha: changes.reduce(Balance(0)) { $0 + $1.alpha },
            netuid: target.netuid
        )
    }

    func claimedAmounts(
        in decodedEvents: [SubtensorDecodedEvent],
        target: SubtensorOutcomeTarget
    ) -> SubtensorExecutedAmounts? {
        let claims = decodedEvents.compactMap { $0.basketClaimedTao(matching: target) }

        let tao: Balance? = claims.isEmpty
            ? decodedEvents.lazy.compactMap { $0.rootClaimedTao(by: target.coldkey) }.first
            : claims.reduce(Balance(0), +)

        return tao.map { SubtensorExecutedAmounts(tao: $0, alpha: $0, netuid: target.netuid) }
    }

    func novaFeePaid(in decodedEvents: [SubtensorDecodedEvent]) -> Balance? {
        guard let novaFeeBeneficiary else {
            return nil
        }

        let fees = decodedEvents.compactMap { $0.transferAmount(from: coldkey, to: novaFeeBeneficiary) }

        return fees.isEmpty ? nil : fees.reduce(Balance(0), +)
    }

    func transactionFeePaid(in decodedEvents: [SubtensorDecodedEvent]) -> Balance? {
        decodedEvents.lazy.compactMap { $0.transactionFee(paidBy: coldkey) }.first
    }
}

private struct SubtensorStakeChange {
    let tao: Balance
    let alpha: Balance
}

private struct SubtensorOutcomeTarget {
    enum Kind {
        case stake
        case unstake
        case claim
    }

    let kind: Kind
    let coldkey: AccountId
    let hotkeys: Set<AccountId>
    let netuid: UInt16

    func matches(coldkey eventColdkey: AccountId, hotkey eventHotkey: AccountId, netuid eventNetuid: UInt16) -> Bool {
        coldkey == eventColdkey && hotkeys.contains(eventHotkey) && netuid == eventNetuid
    }
}

private extension SubtensorOutcomeTarget {
    init(operation: SubtensorOperation, coldkey: AccountId) {
        let rootNetuid = SubtensorPallet.rootNetuid

        switch operation {
        case let .rootStake(hotkey, _):
            self.init(kind: .stake, coldkey: coldkey, hotkeys: [hotkey], netuid: rootNetuid)
        case let .rootUnstake(hotkey, _):
            self.init(kind: .unstake, coldkey: coldkey, hotkeys: [hotkey], netuid: rootNetuid)
        case let .rootUnstakeGroup(exits, partials):
            self.init(
                kind: .unstake,
                coldkey: coldkey,
                hotkeys: Self.hotkeys(exits: exits, partials: partials),
                netuid: rootNetuid
            )
        case let .subnetBuy(hotkey, netuid, _, _, _):
            self.init(kind: .stake, coldkey: coldkey, hotkeys: [hotkey], netuid: netuid)
        case let .subnetSell(hotkey, netuid, _, _, _, _):
            self.init(kind: .unstake, coldkey: coldkey, hotkeys: [hotkey], netuid: netuid)
        case let .subnetSellGroup(exits, partials, netuid, _, _, _):
            self.init(
                kind: .unstake,
                coldkey: coldkey,
                hotkeys: Self.hotkeys(exits: exits, partials: partials),
                netuid: netuid
            )
        case let .rootClaim(hotkey):
            self.init(kind: .claim, coldkey: coldkey, hotkeys: [hotkey], netuid: rootNetuid)
        }
    }

    static func hotkeys(exits: [AccountId], partials: [SubtensorUnstakeSlice]) -> Set<AccountId> {
        Set(exits + partials.map(\.hotkey))
    }
}

private enum SubtensorDecodedEvent {
    case stakeAdded(SubtensorPallet.StakeAddedEvent)
    case stakeRemoved(SubtensorPallet.StakeRemovedEvent)
    case basketClaimed(SubtensorPallet.BasketClaimedEvent)
    case rootClaimed(SubtensorPallet.RootClaimedEvent)
    case alphaFeePaid(SubtensorPallet.TransactionFeePaidWithAlphaEvent)
    case transactionFeePaid(TransactionPaymentPallet.TransactionFeePaid)
    case transfer(BalancesPallet.TransferEvent)

    func alphaFeePaid(by coldkey: AccountId) -> SubtensorPallet.TransactionFeePaidWithAlphaEvent? {
        guard case let .alphaFeePaid(fee) = self, fee.who == coldkey else {
            return nil
        }

        return fee
    }

    func transactionFee(paidBy coldkey: AccountId) -> Balance? {
        guard case let .transactionFeePaid(fee) = self, fee.payee == coldkey else {
            return nil
        }

        return fee.amount
    }

    func isStakeRemoved(by coldkey: AccountId, netuid: UInt16) -> Bool {
        guard case let .stakeRemoved(removed) = self else {
            return false
        }

        return removed.coldkey == coldkey && removed.netuid == netuid
    }

    func stakeAdded(matching target: SubtensorOutcomeTarget) -> SubtensorStakeChange? {
        guard
            case let .stakeAdded(added) = self,
            target.matches(coldkey: added.coldkey, hotkey: added.hotkey, netuid: added.netuid) else {
            return nil
        }

        return SubtensorStakeChange(tao: added.tao, alpha: added.alpha)
    }

    func stakeRemoved(matching target: SubtensorOutcomeTarget) -> SubtensorStakeChange? {
        guard
            case let .stakeRemoved(removed) = self,
            target.matches(coldkey: removed.coldkey, hotkey: removed.hotkey, netuid: removed.netuid) else {
            return nil
        }

        return SubtensorStakeChange(tao: removed.tao, alpha: removed.alpha + removed.fee)
    }

    func basketClaimedTao(matching target: SubtensorOutcomeTarget) -> Balance? {
        guard
            case let .basketClaimed(claimed) = self,
            claimed.coldkey == target.coldkey,
            target.hotkeys.contains(claimed.hotkey) else {
            return nil
        }

        return claimed.tao
    }

    func rootClaimedTao(by coldkey: AccountId) -> Balance? {
        guard case let .rootClaimed(claimed) = self, claimed.coldkey == coldkey else {
            return nil
        }

        return claimed.tao
    }

    func transferAmount(from sender: AccountId, to receiver: AccountId) -> Balance? {
        guard case let .transfer(transfer) = self, transfer.sender == sender, transfer.receiver == receiver else {
            return nil
        }

        return transfer.amount
    }
}
