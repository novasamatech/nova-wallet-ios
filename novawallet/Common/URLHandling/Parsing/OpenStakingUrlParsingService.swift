import Foundation

final class OpenStakingUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func cancel() {}

    func parse(
        url _: URL,
        completion: @escaping (Result<UrlHandlingScreen, DeeplinkParseError>) -> Void
    ) {
        completion(.success(.staking))
    }
}
