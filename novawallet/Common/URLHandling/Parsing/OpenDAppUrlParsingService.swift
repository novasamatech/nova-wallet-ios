import Foundation
import RobinHood

final class OpenDAppUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let dAppProvider: AnySingleValueProvider<DAppList>

    enum Key {
        static let url = "url"
    }

    convenience init() {
        let dAppsUrl = ApplicationConfig.shared.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )
        self.init(dAppProvider: dAppProvider)
    }

    init(dAppProvider: AnySingleValueProvider<DAppList>) {
        self.dAppProvider = dAppProvider
    }

    func parse(url: URL) -> Result<UrlHandlingScreen, DeeplinkParseError> {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            return .failure(.openGovScreen(.emptyQueryParameters))
        }

        let dAppUrl = query.first(where: {
            $0.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(Key.url) == .orderedSame
        })?.value.map { URL(string: $0) }

        guard let dAppUrl = dAppUrl else {
            return .failure(.openDAppScreen(.invalidURL))
        }

        let semaphore = DispatchSemaphore(value: 0)

        var result: Result<UrlHandlingScreen, DeeplinkParseError>?
        _ = dAppProvider.fetch { fetchingResult in
            switch fetchingResult {
            case let .success(list):
                if let dApp = list?.dApps.first(where: { $0.url == dAppUrl }) {
                    result = .success(.dApp(dApp))
                } else {
                    result = .failure(.openDAppScreen(.unknownURL))
                }
            case .failure, .none:
                result = .failure(.openDAppScreen(.loadListFailed))
            }

            semaphore.signal()
        }

        semaphore.wait()

        return result ?? .failure(.openDAppScreen(.loadListFailed))
    }
}
