import Foundation
import RobinHood

final class OpenDAppUrlParsingService: OpenScreenUrlParsingServiceProtocol, AnyProviderAutoCleaning {
    private var dAppProvider: AnySingleValueProvider<DAppList>?

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

    func cancel() {
        clear(singleValueProvider: &dAppProvider)
    }

    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, DeeplinkParseError>) -> Void
    ) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            completion(.failure(.openGovScreen(.emptyQueryParameters)))
            return
        }

        let dAppUrl = query.first(where: {
            $0.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(Key.url) == .orderedSame
        })?.value.map { URL(string: $0) }

        guard let dAppUrl = dAppUrl else {
            completion(.failure(.openDAppScreen(.invalidURL)))
            return
        }

        subscribeDApps { result in
            switch result {
            case let .success(list):
                if let dApp = list?.dApps.first(where: { $0.url == dAppUrl }) {
                    completion(.success(.dApp(dApp)))
                } else {
                    completion(.failure(.openDAppScreen(.unknownURL)))
                }
            case .failure:
                completion(.failure(.openDAppScreen(.loadListFailed)))
            }
        }
    }

    private func subscribeDApps(completion: @escaping (Result<DAppList?, Error>) -> Void) {
        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { changes in
            if let result = changes.reduceToLastChange() {
                completion(.success(result))
            } else {
                completion(.success(nil))
            }
        }

        let failureClosure: (Error) -> Void = { error in
            completion(.failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        dAppProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        dAppProvider?.refresh()
    }
}
