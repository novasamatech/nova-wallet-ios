import Foundation
import BigInt
import SubstrateSdk

protocol CrowdloanBonusServiceProtocol: AnyObject {
    var bonusRate: Decimal { get }
    var termsURL: URL { get }
    var referralCode: String? { get }
    var defaultReferralCode: String? { get }
    var rewardDestinationAddress: String? { get }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void)
    func applyOffchainBonusForContribution(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    )

    func applyOnchainBonusForContribution(
        amount: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol

    func provideSignature(
        contribution: BigUInt,
        closure: @escaping (Result<MultiSignature?, Error>) -> Void
    )
}

extension CrowdloanBonusServiceProtocol {
    func provideSignature(
        contribution _: BigUInt,
        closure: @escaping (Result<MultiSignature?, Error>) -> Void
    ) {
        closure(.success(nil))
    }

    var rewardDestinationAddress: String? { nil }
}
