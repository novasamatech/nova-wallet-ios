import Foundation
import Operation_iOS

final class OpenAHMUrlParsingService {
    private let migrationInfoRepository: AHMInfoRepositoryProtocol
    private let operationQueue: OperationQueue

    private let callStore = CancellableCallStore()

    init(
        migrationInfoRepository: AHMInfoRepositoryProtocol = AHMInfoRepository.shared,
        operationQueue: OperationQueue
    ) {
        self.migrationInfoRepository = migrationInfoRepository
        self.operationQueue = operationQueue
    }
    
    deinit {
        callStore.clear()
    }
}

// MARK: - OpenScreenUrlParsingServiceProtocol

extension OpenAHMUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            completion(.failure(.openDAppScreen(.invalidURL)))
            return
        }

        let sourceChainId: ChainModel.Id? = query.first {
            $0.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == UniversalLink.Screen.assetHubMigration.rawValue
        }?.value

        guard let sourceChainId else {
            completion(.failure(.openAHMScreen(.migrationDataNotFound)))
            return
        }

        let fetchInfoWrapper = migrationInfoRepository.fetch(by: sourceChainId)

        executeCancellable(
            wrapper: fetchInfoWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { result in
            guard case let .success(info) = result, let info else {
                completion(.failure(.openAHMScreen(.migrationDataNotFound)))
                return
            }

            let navigation = AHMNavigation(config: info)

            completion(.success(.assetHubMigration(navigation)))
        }
    }

    func cancel() {
        callStore.cancel()
    }
}
