import Foundation
import BigInt
import SubstrateSdk

extension ExtrinsicProcessor {
    func findFee(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> BigUInt? {
        if let fee = findFeeOfBalancesWithdraw(
            for: index,
            sender: sender,
            eventRecords: eventRecords,
            metadata: metadata
        ) {
            return fee
        } else {
            return findFeeOfBalancesTreasuryDeposit(
                for: index,
                eventRecords: eventRecords,
                metadata: metadata
            )
        }
    }

    private func findFeeOfBalancesWithdraw(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> BigUInt? {
        let withdraw = EventCodingPath.balancesWithdraw
        let closure: (EventRecord) -> Bool = { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            guard eventPath.moduleName == withdraw.moduleName,
                  eventPath.eventName == withdraw.eventName else {
                return false
            }

            guard let event = try? record.event.params.map(to: BalancesWithdrawEvent.self) else {
                return false
            }

            return event.accountId == sender
        }

        guard
            let record = eventRecords.first(where: closure),
            let event = try? record.event.params.map(to: BalancesWithdrawEvent.self) else {
            return nil
        }

        return event.amount
    }

    private func findFeeOfBalancesTreasuryDeposit(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> BigUInt? {
        let balances = EventCodingPath.balancesDeposit

        let maybeBalancesDeposit: BigUInt? = eventRecords.last { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath.moduleName == balances.moduleName &&
                eventPath.eventName == balances.eventName
        }.map { record in
            let event = try? record.event.params.map(to: BalanceDepositEvent.self)
            return event?.amount ?? 0
        }

        let treasury = EventCodingPath.treasuryDeposit

        let maybeTreasuryDeposit: BigUInt? = eventRecords.last { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath.moduleName == treasury.moduleName &&
                eventPath.eventName == treasury.eventName
        }.map { record in
            let event = try? record.event.params.map(to: TreasuryDepositEvent.self)
            return event?.amount ?? 0
        }

        var deposits: [BigUInt] = []

        if let balances = maybeBalancesDeposit {
            deposits.append(balances)
        }

        if let treasury = maybeTreasuryDeposit {
            deposits.append(treasury)
        }

        return !deposits.isEmpty ? deposits.reduce(0, +) : nil
    }
}
