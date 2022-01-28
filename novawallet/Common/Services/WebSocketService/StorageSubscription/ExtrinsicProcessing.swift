import Foundation
import SubstrateSdk
import BigInt

struct ExtrinsicProcessingResult {
    let extrinsic: Extrinsic
    let callPath: CallCodingPath
    let fee: BigUInt?
    let peerId: AccountId?
    let isSuccess: Bool
}

protocol ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult?
}

final class ExtrinsicProcessor {
    let accountId: Data
    let isEthereumBased: Bool

    init(accountId: Data, isEthereumBased: Bool) {
        self.accountId = accountId
        self.isEthereumBased = isEthereumBased
    }

    private func matchStatus(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> Bool? {
        eventRecords.filter { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return [.extrisicSuccess, .extrinsicFailed].contains(eventPath)
        }.first.map { metadata.createEventCodingPath(from: $0.event) == .extrisicSuccess }
    }

    private func findFee(
        for index: UInt32,
        sender: AccountId,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol
    ) -> BigUInt {
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
    ) -> BigUInt {
        let balances = EventCodingPath.balancesDeposit

        let balancesDeposit: BigUInt = eventRecords.last { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath.moduleName == balances.moduleName &&
                eventPath.eventName == balances.eventName
        }.map { record in
            let event = try? record.event.params.map(to: BalanceDepositEvent.self)
            return event?.amount ?? 0
        } ?? 0

        let treasury = EventCodingPath.treasuryDeposit

        let treasuryDeposit: BigUInt = eventRecords.last { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return eventPath.moduleName == treasury.moduleName &&
                eventPath.eventName == treasury.eventName
        }.map { record in
            let event = try? record.event.params.map(to: TreasuryDepositEvent.self)
            return event?.amount ?? 0
        } ?? 0

        return balancesDeposit + treasuryDeposit
    }

    private func matchTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: runtimeJsonContext.toRawContext()
            ).accountId

            let parsingResult: (CallCodingPath, Bool, AccountId?) = try {
                let call = try extrinsic.call.map(
                    to: RuntimeCall<TransferCall>.self,
                    with: runtimeJsonContext.toRawContext()
                )
                let callAccountId = call.args.dest.accountId
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
                let isAccountMatched = accountId == maybeSender || accountId == callAccountId

                return (callPath, isAccountMatched, callAccountId)
            }()

            let callPath = parsingResult.0
            let isAccountMatched = parsingResult.1
            let callAccountId = parsingResult.2

            guard
                callPath.isTransfer,
                isAccountMatched,
                let sender = maybeSender,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata
            )

            let peerId = accountId == sender ? callAccountId : sender

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: peerId,
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }

    private func matchExtrinsic(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadataProtocol,
        runtimeJsonContext: RuntimeJsonContext
    ) -> ExtrinsicProcessingResult? {
        do {
            let maybeSender: AccountId? = try extrinsic.signature?.address.map(
                to: MultiAddress.self,
                with: runtimeJsonContext.toRawContext()
            ).accountId

            let call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == maybeSender

            guard
                let sender = maybeSender,
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                sender: sender,
                eventRecords: eventRecords,
                metadata: metadata
            )

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: nil,
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }
}

extension ExtrinsicProcessor: ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let decoder = try coderFactory.createDecoder(from: extrinsicData)
            let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)

            let runtimeJsonContext = coderFactory.createRuntimeJsonContext()

            if let processingResult = matchTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata,
                runtimeJsonContext: runtimeJsonContext
            ) {
                return processingResult
            }

            return matchExtrinsic(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata,
                runtimeJsonContext: runtimeJsonContext
            )
        } catch {
            return nil
        }
    }
}
