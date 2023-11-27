import Foundation

final class OpenGovernanceUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol

    enum QueryKey {
        static let chainid = "chainid"
        static let referendumIndex = "id"
        static let governanceType = "type"
    }

    enum ParsingGovernanceType: UInt8 {
        case openGov = 0
        case democracy = 1
    }

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }

    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            completion(.failure(.openGovScreen(.invalidChainId)))
            return
        }

        let queryItems = query.reduce(into: [String: String]()) {
            $0[$1.name.lowercased()] = $1.value ?? ""
        }

        guard let chainId = queryItems[QueryKey.chainid],
              !chainId.isEmpty else {
            completion(.failure(.openGovScreen(.invalidChainId)))
            return
        }

        guard let referendumIndexString = queryItems[QueryKey.referendumIndex],
              let referendumIndex = UInt(referendumIndexString) else {
            completion(.failure(.openGovScreen(.invalidReferendumId)))
            return
        }

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            guard let self = self else {
                return
            }
            let chains: [ChainModel] = changes.allChangedItems()

            guard let chainModel = chains.first(where: { $0.chainId == chainId }) else {
                return
            }

            self.chainRegistry.chainsUnsubscribe(self)
            let type = queryItems[QueryKey.governanceType]
            switch Self.governanceType(for: chainModel, type: type) {
            case let .failure(error):
                break
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
    ) -> Result<GovernanceType, OpenScreenUrlParsingError.GovScreenError> {
        let governanceType = type.map { UInt8($0) }?.map { ParsingGovernanceType(rawValue: $0) }
        switch governanceType {
        case .openGov:
            return chain.hasGovernanceV2 ? .success(.governanceV2) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV2.rawValue))
        case .democracy:
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
