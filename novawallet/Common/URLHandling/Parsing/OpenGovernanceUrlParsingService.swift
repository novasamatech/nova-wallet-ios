import Foundation

final class OpenGovernanceUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let chainRegistryClosure: ChainRegistryLazyClosure

    enum Key {
        static let chainid = "chainid"
        static let referendumIndex = "id"
        static let governanceType = "type"
    }

    init(chainRegistryClosure: @escaping ChainRegistryLazyClosure) {
        self.chainRegistryClosure = chainRegistryClosure
    }

    func cancel() {
        chainRegistryClosure().chainsUnsubscribe(self)
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

        let queryItems = query.reduce(into: [String: String]()) {
            $0[$1.name.lowercased()] = $1.value ?? ""
        }

        guard let chainId = queryItems[Key.chainid],
              !chainId.isEmpty else {
            completion(.failure(.openGovScreen(.invalidChainId)))
            return
        }

        guard let referendumIndexString = queryItems[Key.referendumIndex],
              let referendumIndex = UInt(referendumIndexString) else {
            completion(.failure(.openGovScreen(.invalidReferendumId)))
            return
        }

        chainRegistryClosure().chainsSubscribe(
            self,
            runningInQueue: .main
        ) { changes in
            let chains: [ChainModel] = changes.allChangedItems()

            guard let chainModel = chains.first(where: { $0.chainId == chainId }) else {
                completion(.failure(.openGovScreen(.invalidChainId)))
                return
            }

            let type = queryItems[Key.governanceType]?.trimmingCharacters(in: .whitespacesAndNewlines)
            switch Self.governanceType(for: chainModel, type: type) {
            case let .failure(error):
                completion(.failure(.openGovScreen(error)))
            case let .success(type):
                let state = ReferendumsInitState(
                    chainId: chainId,
                    referendumIndex: referendumIndex,
                    governance: type
                )
                completion(.success(.gov(state)))
            }
        }
    }

    private static func governanceType(
        for chain: ChainModel,
        type: String?
    ) -> Result<GovernanceType, DeeplinkParseError.GovScreenError> {
        switch type {
        case "0":
            return chain.hasGovernanceV2 ? .success(.governanceV2) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV2.rawValue))
        case "1":
            return chain.hasGovernanceV1 ? .success(.governanceV1) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV1.rawValue))
        default:
            if chain.hasGovernanceV1, chain.hasGovernanceV2 {
                return .failure(.govTypeIsAmbiguous)
            } else {
                return .success(chain.hasGovernanceV2 ? .governanceV2 : .governanceV1)
            }
        }
    }
}
