import Foundation
import Foundation_iOS
import Keystore_iOS

final class OpenGovernanceUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    private let chainRegistry: ChainRegistryProtocol
    private let settings: SettingsManagerProtocol

    let defaultChainId: ChainModel.Id

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SettingsManagerProtocol,
        defaultChainId: ChainModel.Id = UniversalLink.GovScreen.defaultChainId
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

        guard let referendumIndexString = queryItems[UniversalLink.GovScreen.QueryKey.referendumIndex],
              let referendumIndex = UInt32(referendumIndexString) else {
            completion(.failure(.openGovScreen(.invalidReferendumId)))
            return
        }

        let chainId = queryItems[UniversalLink.GovScreen.QueryKey.chainid] ?? defaultChainId

        handle(
            for: chainId,
            type: queryItems[UniversalLink.GovScreen.QueryKey.governanceType]
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

        let governanceType = type.map { UInt8($0) }?.map { UniversalLink.GovScreen.GovType(rawValue: $0) } ?? nil
        switch governanceType {
        case .openGov:
            return chain.hasGovernanceV2 ? .success(.governanceV2) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV2.rawValue))
        case .democracy:
            return chain.hasGovernanceV1 ? .success(.governanceV1) :
                .failure(.chainNotSupportsGovType(type: GovernanceType.governanceV1.rawValue))
        case nil:
            if let type, !type.isEmpty {
                return .failure(.chainNotSupportsGovType(type: type))
            }

            if let defaultType = UniversalLink.GovScreen.defaultGovTypeForChain(chain) {
                return .success(defaultType)
            } else {
                return .failure(.govTypeIsNotSpecified)
            }
        }
    }
}
