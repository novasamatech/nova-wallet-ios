import Foundation
import SubstrateSdk
import BigInt

struct ExtrinsicProcessingResult {
    let sender: AccountId
    let callPath: CallCodingPath
    let call: JSON
    let extrinsicHash: Data?
    let fee: BigUInt?
    let peerId: AccountId?
    let amount: BigUInt?
    let isSuccess: Bool
    let assetId: UInt32
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
    let chain: ChainModel

    init(accountId: Data, chain: ChainModel) {
        self.accountId = accountId
        self.chain = chain
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

            if let processingResult = matchBalancesTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata,
                context: runtimeJsonContext
            ) {
                return processingResult
            }

            if let processingResult = matchAssetsTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata,
                context: runtimeJsonContext
            ) {
                return processingResult
            }

            if let processingResult = matchOrmlTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                codingFactory: coderFactory
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
