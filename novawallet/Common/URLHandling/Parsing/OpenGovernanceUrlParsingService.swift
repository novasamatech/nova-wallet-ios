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

    func parse(url: URL) -> Result<UrlHandlingScreen, DeeplinkParseError> {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            return .failure(.openGovScreen(.emptyQueryParameters))
        }

        let queryItems = query.reduce(into: [String: String]()) {
            $0[$1.name.lowercased()] = $1.value ?? ""
        }

        guard let chainId = queryItems[Key.chainid],
              !chainId.isEmpty else {
            return .failure(.openGovScreen(.invalidChainId))
        }

        guard let referendumIndexString = queryItems[Key.referendumIndex],
              let referendumIndex = UInt(referendumIndexString) else {
            return .failure(.openGovScreen(.invalidReferendumId))
        }

        guard let chainModel = chainRegistryClosure().getChain(for: chainId) else {
            return .failure(.openGovScreen(.invalidChainId))
        }

        let type = queryItems[Key.governanceType]?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch governanceType(for: chainModel, type: type) {
        case let .failure(error):
            return .failure(.openGovScreen(error))
        case let .success(type):
            let state = ReferendumsInitState(
                chainId: chainId,
                referendumIndex: referendumIndex,
                governance: type
            )
            return .success(.gov(state))
        }
    }

    private func governanceType(
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
