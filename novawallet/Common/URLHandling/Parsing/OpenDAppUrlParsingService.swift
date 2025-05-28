import Foundation
import Operation_iOS

final class OpenDAppUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            completion(.failure(.openDAppScreen(.invalidURL)))
            return
        }

        let dAppUrl = query.first(where: {
            $0.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(UniversalLink.DAppScreen.QueryKey.url) == .orderedSame
        })?.value.map { URL(string: $0) } ?? nil

        guard let dAppUrl = dAppUrl, dAppUrl.host != nil else {
            completion(.failure(.openDAppScreen(.invalidURL)))
            return
        }

        let model = DAppNavigation(url: dAppUrl)

        completion(.success(.dApp(model)))
    }

    func cancel() {}
}
