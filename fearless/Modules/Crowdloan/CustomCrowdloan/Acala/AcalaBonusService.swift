import Foundation
import RobinHood

final class AcalaBonusService: KaruraBonusService {
    override var defaultReferralCode: String {
        "0xbcb330a49b5766dcd63fff92cf95243ec2a29c4131f19155724095e5cfd5197a"
    }

    override var baseURL: URL {
        #if DEBUG
            return URL(string: "https://crowdloan.aca-dev.network")!
        #else
            return URL(string: "https://crowdloan.aca-api.network")!
        #endif
    }
}

final class AcalaRequestModifier: NetworkRequestModifierProtocol {
    func modify(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.addValue(
            "Bearer \(AcalaKeys.authToken)",
            forHTTPHeaderField: "Authorization"
        )
        return modifiedRequest
    }
}
