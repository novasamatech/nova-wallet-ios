import Foundation

protocol DeeplinkOpenScreenParsingServiceProtocol {
    func parse(url: URL) -> Result<UrlHandlingScreen, DeeplinkParseError>
}

enum DeeplinkParseError: Error {
    case openGovScreen(GovScreenError)

    enum GovScreenError: Error {
        case govTypeIsAmbiguous
        case emptyQueryParameters
        case invalidChainId
        case invalidReferendumId
        case chainNotSupportedType(type: String)
        case chainNotFound
    }
}

final class StakingUrlHandlingScreen: DeeplinkOpenScreenParsingServiceProtocol {
    func parse(url _: URL) -> Result<UrlHandlingScreen, DeeplinkParseError> {
        .success(.staking)
    }
}

final class GovUrlHandlingScreen: DeeplinkOpenScreenParsingServiceProtocol {
    private let registryClosure: ChainRegistryLazyClosure

    init(registryClosure: @escaping ChainRegistryLazyClosure) {
        self.registryClosure = registryClosure
    }

    func parse(url: URL) -> Result<UrlHandlingScreen, DeeplinkParseError> {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let query = urlComponents.queryItems else {
            return .failure(.openGovScreen(.emptyQueryParameters))
        }

        let queryItems = query.reduce(into: [String: String?]()) {
            $0[$1.name.lowercased()] = $1.value
        }

        guard let optChainId = queryItems["chainid"],
              let chainId = optChainId else {
            return .failure(.openGovScreen(.invalidChainId))
        }

        guard let idValue = queryItems["id"],
              let id = idValue,
              let parsedId = UInt(id) else {
            return .failure(.openGovScreen(.invalidReferendumId))
        }

        let type = queryItems["type"].flatMap { $0 }

        let registry = registryClosure()
        guard let chainModel = registry.getChain(for: chainId) else {
            return .failure(.openGovScreen(.invalidReferendumId))
        }

        switch governanceType(for: chainModel, type: type) {
        case let .failure(error):
            return .failure(.openGovScreen(error))
        case let .success(type):
            let state = ReferendumsInitState(
                chainId: chainId,
                referendumId: parsedId,
                governance: type
            )
            return .success(.gov(state))
        }
    }

    private func governanceType(for chain: ChainModel, type: String?) -> Result<GovernanceType, DeeplinkParseError.GovScreenError> {
        let type = type.map { Int($0) } ?? nil
        switch type {
        case 1:
            return chain.hasGovernanceV1 ? .success(.governanceV1) :
                .failure(.chainNotSupportedType(type: GovernanceType.governanceV1.rawValue))
        case 0:
            return chain.hasGovernanceV2 ? .success(.governanceV2) :
                .failure(.chainNotSupportedType(type: GovernanceType.governanceV2.rawValue))
        default:
            if chain.hasGovernanceV1, chain.hasGovernanceV2 {
                return .failure(.govTypeIsAmbiguous)
            } else {
                return .success(chain.hasGovernanceV2 ? .governanceV2 : .governanceV1)
            }
        }
    }
}
