import Foundation
import BigInt
import SubstrateSdk

extension ExtrinsicProcessor {
    func findAssetsCustomFee(
        for index: UInt32,
        eventRecords: [EventRecord],
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> Fee? {
        let metadata = codingFactory.metadata
        let context = codingFactory.createRuntimeJsonContext()
        let extrinsicEvents = eventRecords.filter { $0.extrinsicIndex == index }
        let path = AssetTxPaymentPallet.assetTxFeePaidEvent

        guard
            let record = extrinsicEvents.last(where: { metadata.eventMatches($0.event, path: path) }),
            let feePaidEvent: AssetTxPaymentPallet.AssetTxFeePaid = try? ExtrinsicExtraction.getEventParams(
                from: record.event,
                context: context
            )
        else {
            return nil
        }

        let feeAsset = AssetHubTokensConverter.convertToLocalAsset(
            for: feePaidEvent.assetId,
            on: chain,
            using: codingFactory
        )

        return Fee(
            amount: feePaidEvent.actualFee,
            assetId: feeAsset?.asset.assetId
        )
    }

    func findHydraCustomFee(
        in events: [EventRecord],
        swapEvents: Set<EventCodingPath>,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> Fee? {
        let metadata = codingFactory.metadata

        let swapIndex = events.lastIndex { metadata.eventMatches($0.event, oneOf: swapEvents) } ?? 0

        let feePaidPath = TransactionPaymentPallet.feePaidPath
        let optFeePaidIndex = events.lastIndex { metadata.eventMatches($0.event, path: feePaidPath) }

        guard
            let feePaidIndex = optFeePaidIndex,
            swapIndex < feePaidIndex
        else {
            return nil
        }

        let depositedPath = TokensPallet.depositedEventPath
        let optDepositEvent = events[swapIndex ..< feePaidIndex].first {
            metadata.eventMatches($0.event, path: depositedPath)
        }

        let context = codingFactory.createRuntimeJsonContext()

        guard
            let depositedEvent = optDepositEvent,
            let depositedModel: TokensPallet.DepositedEvent<StringScaleMapper<BigUInt>> =
            try? ExtrinsicExtraction.getEventParams(
                from: depositedEvent.event,
                context: context
            )
        else {
            return nil
        }

        let assetId = try HydraDxTokenConverter.convertToLocal(
            for: depositedModel.currencyId.value,
            chain: chain,
            codingFactory: codingFactory
        ).assetId

        return Fee(
            amount: depositedModel.amount,
            assetId: assetId
        )
    }
}
