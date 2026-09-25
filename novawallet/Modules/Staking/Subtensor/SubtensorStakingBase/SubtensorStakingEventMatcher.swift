import Foundation
import SubstrateSdk

struct SubtensorStakingEventMatcher: ExtrinsicEventsMatching {
    static let matchedEvents: Set<EventCodingPath> = [
        SubtensorStakingPallet.stakeAddedEventPath,
        SubtensorStakingPallet.stakeRemovedEventPath,
        SubtensorStakingPallet.rootClaimedEventPath,
        SubtensorStakingPallet.transactionFeePaidWithAlphaEventPath,
        BalancesPallet.balancesTransfer,
        UtilityPallet.batchInterruptedEventPath,
        UtilityPallet.itemFailedEventPath
    ]

    func match(event: Event, using codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.metadata.eventMatches(event, oneOf: Self.matchedEvents)
    }
}

enum SubtensorExecutedOutcomeParser {
    static func parseOutcome(
        from events: [Event],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> SubtensorExecutedOutcome? {
        let metadata = codingFactory.metadata
        let context = codingFactory.createRuntimeJsonContext()

        // the dispatch's own event is emitted after any pre-dispatch fee-in-alpha
        // StakeRemoved, so the last match carries the executed amount
        for event in events.reversed() {
            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.stakeAddedEventPath),
                let added = try? event.params.map(
                    to: SubtensorStakingPallet.StakeAddedEvent.self,
                    with: context.toRawContext()
                ) {
                return .staked(tao: added.tao, alpha: added.alpha, netuid: added.netuid)
            }

            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.stakeRemovedEventPath),
                let removed = try? event.params.map(
                    to: SubtensorStakingPallet.StakeRemovedEvent.self,
                    with: context.toRawContext()
                ) {
                return .unstaked(tao: removed.tao, alpha: removed.alpha, netuid: removed.netuid)
            }

            if
                metadata.eventMatches(event, path: SubtensorStakingPallet.rootClaimedEventPath),
                let claimed = try? event.params.map(
                    to: SubtensorStakingPallet.RootClaimedEvent.self,
                    with: context.toRawContext()
                ) {
                return .claimed(tao: claimed.tao)
            }
        }

        return nil
    }
}

extension SubtensorStakingPallet {
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

extension UtilityPallet {
    static var batchInterruptedEventPath: EventCodingPath {
        EventCodingPath(moduleName: name, eventName: "BatchInterrupted")
    }

    static var itemFailedEventPath: EventCodingPath {
        EventCodingPath(moduleName: name, eventName: "ItemFailed")
    }
}

enum SubtensorStakingOutcomeError: Error {
    case batchInterrupted
}

struct SubtensorStakingOutcomeParser {
    let coldkey: AccountId
    let novaFeeBeneficiary: AccountId?
    let codingFactory: RuntimeCoderFactoryProtocol

    func parse(
        events: [Event],
        for operation: SubtensorStakingOperation,
        extrinsicHash: String?
    ) throws -> SubtensorStakingOperationOutcome {
        let context = codingFactory.createRuntimeJsonContext().toRawContext()
        let decodedEvents = events.compactMap { decode(event: $0, context: context) }

        for case let .batchFailed(error) in decodedEvents {
            throw error
        }

        let target = SubtensorOutcomeTarget(operation: operation, coldkey: coldkey)
        let alphaFee = decodedEvents.lazy.compactMap { $0.alphaFeePaid(by: coldkey) }.first

        return SubtensorStakingOperationOutcome(
            executed: executedAmounts(in: decodedEvents, target: target, alphaFee: alphaFee),
            claimedTao: claimedTao(in: decodedEvents, target: target),
            novaFeePaid: novaFeePaid(in: decodedEvents),
            alphaFeePaid: alphaFee?.alphaFee,
            extrinsicHash: extrinsicHash
        )
    }
}

private extension SubtensorStakingOutcomeParser {
    func decode(event: Event, context: [CodingUserInfoKey: Any]) -> SubtensorDecodedStakingEvent? {
        let metadata = codingFactory.metadata

        if metadata.eventMatches(event, path: SubtensorStakingPallet.stakeAddedEventPath) {
            return (try? event.params.map(to: SubtensorStakingPallet.StakeAddedEvent.self, with: context))
                .map { .stakeAdded($0) }
        }

        if metadata.eventMatches(event, path: SubtensorStakingPallet.stakeRemovedEventPath) {
            return (try? event.params.map(to: SubtensorStakingPallet.StakeRemovedEvent.self, with: context))
                .map { .stakeRemoved($0) }
        }

        if metadata.eventMatches(event, path: SubtensorStakingPallet.rootClaimedEventPath) {
            return (try? event.params.map(to: SubtensorStakingPallet.RootClaimedEvent.self, with: context))
                .map { .rootClaimed($0) }
        }

        if metadata.eventMatches(event, path: SubtensorStakingPallet.transactionFeePaidWithAlphaEventPath) {
            let eventType = SubtensorStakingPallet.TransactionFeePaidWithAlphaEvent.self

            return (try? event.params.map(to: eventType, with: context)).map { .alphaFeePaid($0) }
        }

        if metadata.eventMatches(event, path: BalancesPallet.balancesTransfer) {
            return (try? event.params.map(to: BalancesPallet.TransferEvent.self, with: context))
                .map { .transfer($0) }
        }

        if metadata.eventMatches(event, path: UtilityPallet.batchInterruptedEventPath) {
            return .batchFailed(dispatchError(from: Array(event.params.arrayValue?.dropFirst() ?? [])))
        }

        if metadata.eventMatches(event, path: UtilityPallet.itemFailedEventPath) {
            return .batchFailed(dispatchError(from: event.params.arrayValue ?? []))
        }

        return nil
    }

    func dispatchError(from errorParams: [JSON]) -> Error {
        let decoder = CallDispatchErrorDecoder(logger: Logger.shared)

        return decoder.decode(errorParams: .arrayValue(errorParams), using: codingFactory) ??
            SubtensorStakingOutcomeError.batchInterrupted
    }

    func executedAmounts(
        in decodedEvents: [SubtensorDecodedStakingEvent],
        target: SubtensorOutcomeTarget,
        alphaFee: SubtensorStakingPallet.TransactionFeePaidWithAlphaEvent?
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
            return nil
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

    func claimedTao(
        in decodedEvents: [SubtensorDecodedStakingEvent],
        target: SubtensorOutcomeTarget
    ) -> Balance? {
        guard target.kind == .claim else {
            return nil
        }

        let claims = decodedEvents.compactMap { $0.claimedTao(by: target.coldkey) }

        return claims.isEmpty ? nil : claims.reduce(Balance(0), +)
    }

    func novaFeePaid(in decodedEvents: [SubtensorDecodedStakingEvent]) -> Balance? {
        guard let novaFeeBeneficiary else {
            return nil
        }

        let fees = decodedEvents.compactMap { $0.transferAmount(from: coldkey, to: novaFeeBeneficiary) }

        return fees.isEmpty ? nil : fees.reduce(Balance(0), +)
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
    let hotkey: AccountId
    let netuid: UInt16

    init(kind: Kind, coldkey: AccountId, hotkey: AccountId, netuid: UInt16) {
        self.kind = kind
        self.coldkey = coldkey
        self.hotkey = hotkey
        self.netuid = netuid
    }

    init(operation: SubtensorStakingOperation, coldkey: AccountId) {
        let rootNetuid = SubtensorStakingPallet.rootNetuid

        switch operation {
        case let .rootStake(hotkey, _):
            self.init(kind: .stake, coldkey: coldkey, hotkey: hotkey, netuid: rootNetuid)
        case let .rootUnstake(hotkey, _), let .rootUnstakeAll(hotkey):
            self.init(kind: .unstake, coldkey: coldkey, hotkey: hotkey, netuid: rootNetuid)
        case let .subnetBuy(hotkey, netuid, _, _):
            self.init(kind: .stake, coldkey: coldkey, hotkey: hotkey, netuid: netuid)
        case let .subnetSell(hotkey, netuid, _, _), let .subnetSellAll(hotkey, netuid, _, _):
            self.init(kind: .unstake, coldkey: coldkey, hotkey: hotkey, netuid: netuid)
        case let .claimRoot(hotkey):
            self.init(kind: .claim, coldkey: coldkey, hotkey: hotkey, netuid: rootNetuid)
        }
    }

    func matches(coldkey eventColdkey: AccountId, hotkey eventHotkey: AccountId, netuid eventNetuid: UInt16) -> Bool {
        coldkey == eventColdkey && hotkey == eventHotkey && netuid == eventNetuid
    }
}

private enum SubtensorDecodedStakingEvent {
    case stakeAdded(SubtensorStakingPallet.StakeAddedEvent)
    case stakeRemoved(SubtensorStakingPallet.StakeRemovedEvent)
    case rootClaimed(SubtensorStakingPallet.RootClaimedEvent)
    case alphaFeePaid(SubtensorStakingPallet.TransactionFeePaidWithAlphaEvent)
    case transfer(BalancesPallet.TransferEvent)
    case batchFailed(Error)

    func alphaFeePaid(by coldkey: AccountId) -> SubtensorStakingPallet.TransactionFeePaidWithAlphaEvent? {
        guard case let .alphaFeePaid(fee) = self, fee.who == coldkey else {
            return nil
        }

        return fee
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

        return SubtensorStakeChange(tao: removed.tao, alpha: removed.alpha)
    }

    func claimedTao(by coldkey: AccountId) -> Balance? {
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
