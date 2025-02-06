import Foundation
import SoraFoundation
import SoraKeystore

final class OpenGovernanceUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let settings: SettingsManagerProtocol

    enum QueryKey {
        static let chainid = "chainid"
        static let referendumIndex = "id"
        static let governanceType = "type"
    }

    enum ParsingGovernanceType: UInt8 {
        case openGov = 0
        case democracy = 1
    }

    let defaultChainId: ChainModel.Id

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SettingsManagerProtocol,
        defaultChainId: ChainModel.Id = KnowChainId.polkadot
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.defaultChainId = defaultChainId
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

        guard let referendumIndexString = queryItems[QueryKey.referendumIndex],
              let referendumIndex = UInt32(referendumIndexString) else {
            completion(.failure(.openGovScreen(.invalidReferendumId)))
            return
        }

        let chainId = queryItems[QueryKey.chainid] ?? defaultChainId

        handle(
            for: chainId,
            type: queryItems[QueryKey.governanceType]
        ) {
            completion(.success(.gov(referendumIndex)))
        }
    }

    func handle(
        for chainId: ChainModel.Id,
        type: String?,
        completion: @escaping () -> Void
    ) {
        handle(
            targetChainClosure: { $0.chainId == chainId },
            type: type,
            completion: completion
        )
    }

    func handle(
        targetChainClosure: @escaping (ChainModel) -> Bool,
        type: String?,
        completion: @escaping () -> Void
    ) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            guard let self = self else {
                return
            }
            let chains: [ChainModel] = changes.allChangedItems()

            guard let chainModel = chains.first(where: targetChainClosure) else {
                return
            }

            self.chainRegistry.chainsUnsubscribe(self)

            switch Self.governanceType(for: chainModel, type: type) {
            case .failure:
                break
            case let .success(type):
                self.settings.governanceChainId = chainModel.chainId
                self.settings.governanceType = type
                completion()
            }
        }
    }

    private static func governanceType(
        for chain: ChainModel,
        type: String?
    ) -> Result<GovernanceType, OpenScreenUrlParsingError.GovScreenError> {
        guard chain.hasGovernance else {
            return .failure(.chainNotSupportsGov)
        }

        let governanceType = type.map { UInt8($0) }?.map { ParsingGovernanceType(rawValue: $0) } ?? nil
        switch governanceType {
        case .openGov:
            return chain.hasGovernanceV2 ? .success(.governanceV2) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV2.rawValue))
        case .democracy:
            return chain.hasGovernanceV1 ? .success(.governanceV1) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV1.rawValue))
        case nil:
            if let type = type, !type.isEmpty {
                return .failure(.chainNotSupportsGovType(type: type))
            }
            if chain.hasGovernanceV2 {
                return .success(.governanceV2)
            } else if chain.hasGovernanceV1 {
                return .success(.governanceV1)
            } else {
                return .failure(.govTypeIsNotSpecified)
            }
        }
    }
}
