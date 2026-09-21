import Foundation
import SubstrateSdk
import BigInt

protocol ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult?
}

final class ExtrinsicProcessor {
    let accountId: AccountId
    let chain: ChainModel
    let assetHubCommissionBeneficiaries: Set<AccountId>
    let logger: LoggerProtocol

    init(
        accountId: AccountId,
        chain: ChainModel,
        assetHubCommissionBeneficiaries: Set<AccountId>? = nil,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.chain = chain
        self.logger = logger

        if let assetHubCommissionBeneficiaries {
            self.assetHubCommissionBeneficiaries = assetHubCommissionBeneficiaries
        } else {
            let resolved = AssetExchangeCommissionConstants.assetHubHistoryBeneficiaries(for: chain.chainId)

            resolved.invalid.forEach {
                logger.error("Invalid Asset Hub commission beneficiary for \(chain.chainId): \($0)")
            }

            self.assetHubCommissionBeneficiaries = resolved.accountIds
        }
    }
}

extension ExtrinsicProcessor: ExtrinsicProcessing {
    // swiftlint:disable:next function_body_length
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

            switch matchAssetHubSwap(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                codingFactory: coderFactory
            ) {
            case let .matched(processingResult):
                return processingResult
            case .unresolved:
                return nil
            case .notMatched:
                break
            }

            if let processingResult = matchHydraSwap(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                codingFactory: coderFactory
            ) {
                return processingResult
            }

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
                codingFactory: coderFactory,
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

            if let processingResult = matchEquilibriumTransfer(
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
