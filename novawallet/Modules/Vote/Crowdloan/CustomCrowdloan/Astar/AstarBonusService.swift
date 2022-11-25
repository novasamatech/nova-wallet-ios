import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class AstarBonusService {
    let defaultReferralCode: String? = "1ChFWeNRLarAPRCTM3bfJmncJbSAbSS9yqjueWz7jX7iTVZ"

    var bonusRate: Decimal { 0.01 }

    var termsURL: URL {
        URL(string: "https://docs.google.com/document/d/1vKZrDqSdh706hg0cqJ_NnxfRSlXR2EThVHwoRl0nAkk")!
    }

    private(set) var referralCode: String?

    let paraId: ParaId
    let chainFormat: ChainFormat
    let operationManager: OperationManagerProtocol

    init(
        paraId: ParaId,
        chainFormat: ChainFormat,
        operationManager: OperationManagerProtocol
    ) {
        self.paraId = paraId
        self.chainFormat = chainFormat
        self.operationManager = operationManager
    }
}

extension AstarBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        do {
            _ = try referralCode.toAccountId(using: chainFormat)
            self.referralCode = referralCode
            closure(.success(()))
        } catch {
            closure(.failure(AstarBonusServiceError.invalidReferral))
        }
    }

    func applyOffchainBonusForContribution(
        amount _: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard let referralCode = referralCode else {
            return builder
        }

        guard let polkadotReferralAccountId = try? referralCode.toAccountId(using: chainFormat) else {
            throw AstarBonusServiceError.invalidReferral
        }

        let addMemo = SubstrateCallFactory().addMemo(to: paraId, memo: polkadotReferralAccountId)

        return try builder.adding(call: addMemo)
    }
}
