import Foundation
import RobinHood

final class OpenDAppUrlParsingService: OpenScreenUrlParsingServiceProtocol, AnyProviderAutoCleaning {
    private let dAppsProvider: AnySingleValueProvider<DAppList>

    enum QueryKey {
        static let url = "url"
    }

    init(dAppsProvider: AnySingleValueProvider<DAppList>) {
        self.dAppsProvider = dAppsProvider
    }

    func cancel() {
        dAppsProvider.removeObserver(self)
    }

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
                .caseInsensitiveCompare(QueryKey.url) == .orderedSame
        })?.value.map { URL(string: $0) }

        guard let dAppUrl = dAppUrl else {
            completion(.failure(.openDAppScreen(.invalidURL)))
            return
        }

        subscribeDApps { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case let .success(list):
                if let dApp = list?.dApps.first(where: { $0.url == dAppUrl }) {
                    self.dAppsProvider.removeObserver(self)
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

        dAppsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}
