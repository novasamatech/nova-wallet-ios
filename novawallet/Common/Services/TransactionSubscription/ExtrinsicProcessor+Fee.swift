import Foundation
import BigInt
import SubstrateSdk

extension ExtrinsicProcessor {
    struct Fee {
        let amount: BigUInt
        let assetId: AssetModel.Id?
    }

    func findFee(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> Fee? {
        if let fee = findTransactionFeePaid(
            for: index,
            eventRecords: eventRecords,
            metadata: metadata,
            runtimeJsonContext: runtimeJsonContext
        ) {
            return fee
        } else if let fee = findFeeOfBalancesWithdraw(
            for: index,
            sender: sender,
            eventRecords: eventRecords,
            metadata: metadata,
            runtimeJsonContext: runtimeJsonContext
        ) {
            return fee
        } else {
            return findFeeOfBalancesTreasuryDeposit(
                for: index,
                eventRecords: eventRecords,
                metadata: metadata,
                runtimeJsonContext: runtimeJsonContext
            )
        }
    }

    func findAssetsFee(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> Fee? {
        findAssetsCustomFee(
            for: index,
            eventRecords: eventRecords,
            codingFactory: codingFactory
        )
            ?? findFee(
                for: index,
                sender: sender,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata,
                runtimeJsonContext: codingFactory.createRuntimeJsonContext()
            )
    }

    func findOrmlFee(
        for params: HydraSwapExtrinsicParsingParams,
        extrinsicIndex: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Fee? {
        try findHydraCustomFee(
            in: eventRecords,
            swapEvents: params.events,
            codingFactory: codingFactory
        )
            ?? findFee(
                for: extrinsicIndex,
                sender: params.sender,
                eventRecords: eventRecords,
                metadata: codingFactory.metadata,
                runtimeJsonContext: codingFactory.createRuntimeJsonContext()
            )
    }

    private func findTransactionFeePaid(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> Fee? {
        let extrinsicEvents = eventRecords.filter { $0.extrinsicIndex == index }

        let path = TransactionPaymentPallet.feePaidPath
        guard
            let record = extrinsicEvents.last(where: { metadata.eventMatches($0.event, path: path) }),
            let feePaidEvent: TransactionPaymentPallet.TransactionFeePaid = try? ExtrinsicExtraction.getEventParams(
                from: record.event,
                context: runtimeJsonContext
            )
        else {
            return nil
        }

        return Fee(
            amount: feePaidEvent.amount,
            assetId: nil
        )
    }

    private func findFeeOfBalancesWithdraw(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> Fee? {
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

            guard let event = try? record.event.params.map(
                to: BalancesWithdrawEvent.self,
                with: runtimeJsonContext.toRawContext()
            ) else {
                return false
            }

            return event.accountId == sender
        }

        guard
            let record = eventRecords.first(where: closure),
            let event = try? record.event.params.map(
                to: BalancesWithdrawEvent.self,
                with: runtimeJsonContext.toRawContext()
            ) else {
            return nil
        }

        return Fee(
            amount: event.amount,
            assetId: nil
        )
    }

    private func findFeeOfBalancesTreasuryDeposit(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> Fee? {
        let balances = EventCodingPath.balancesDeposit

        let maybeBalancesDeposit: BigUInt? = eventRecords.last { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath.moduleName == balances.moduleName &&
                eventPath.eventName == balances.eventName
        }.map { record in
            let event = try? record.event.params.map(
                to: BalanceDepositEvent.self,
                with: runtimeJsonContext.toRawContext()
            )
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
            let event = try? record.event.params.map(
                to: TreasuryDepositEvent.self,
                with: runtimeJsonContext.toRawContext()
            )
            return event?.amount ?? 0
        }

        var deposits: [BigUInt] = []

        if let balances = maybeBalancesDeposit {
            deposits.append(balances)
        }

        if let treasury = maybeTreasuryDeposit {
            deposits.append(treasury)
        }

        let amount: BigUInt? = !deposits.isEmpty ? deposits.reduce(0, +) : nil

        guard let amount else {
            return nil
        }

        return Fee(
            amount: amount,
            assetId: nil
        )
    }
}
