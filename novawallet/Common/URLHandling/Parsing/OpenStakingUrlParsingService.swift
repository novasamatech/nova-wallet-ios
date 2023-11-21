import Foundation

final class OpenStakingUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func parse(url _: URL) -> Result<UrlHandlingScreen, DeeplinkParseError> {
        .success(.staking)
    }
}
