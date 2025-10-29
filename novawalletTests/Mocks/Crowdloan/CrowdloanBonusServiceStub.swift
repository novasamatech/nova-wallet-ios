import Foundation
@testable import novawallet
import BigInt
import SubstrateSdk

final class CrowdloanBonusServiceStub: CrowdloanBonusServiceProtocol {
    var termsURL: URL { URL(string: "https://google.com")! }

    var bonusRate: Decimal { 0.05 }

    private(set) var referralCode: String?
    var defaultReferralCode: String? { nil }

    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        self.referralCode = referralCode

        closure(.success(()))
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
        builder
    }
}
