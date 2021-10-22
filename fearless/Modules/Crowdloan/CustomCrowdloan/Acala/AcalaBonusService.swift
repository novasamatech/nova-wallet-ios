import Foundation

final class AcalaBonusService: KaruraBonusService {
    override var defaultReferralCode: String {
        "0xbcb330a49b5766dcd63fff92cf95243ec2a29c4131f19155724095e5cfd5197a"
    }

    override var baseURL: URL {
        #if DEBUG
            return URL(string: "https://crowdloan.aca-dev.network")!
        #endif
    }
}
