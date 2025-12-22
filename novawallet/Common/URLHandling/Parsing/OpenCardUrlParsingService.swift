import Foundation

final class OpenCardUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func cancel() {}

    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let providerParam = components?.queryItems?.first(
            where: { $0.name == UniversalLink.CardScreen.QueryKey.provider }
        )?.value

        guard let providerParam = providerParam else {
            completion(.success(.card(nil)))
            return
        }

        guard let navigation = PayCardNavigation(rawValue: providerParam) else {
            completion(.failure(.cardScreen(.unsupportedProvider)))
            return
        }

        completion(.success(.card(navigation)))
    }
}
