import Foundation

enum UniversalLink {
    enum Action: String {
        case open
        case create
    }

    enum Entity: String {
        case wallet
    }

    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
        case card
        case assetHubMigration = "ahm"
    }

    enum GovScreen {
        enum GovType: UInt8 {
            case openGov = 0
            case democracy = 1
        }

        enum QueryKey {
            static let chainid = "chainid"
            static let referendumIndex = "id"
            static let governanceType = "type"
        }

        static var defaultChainId: ChainModel.Id { KnowChainId.polkadot }

        static func urlGovType(_ chainModel: ChainModel, type: GovernanceType) -> GovType? {
            let defaultType = defaultGovTypeForChain(chainModel)

            guard defaultType != type else {
                return nil
            }

            switch type {
            case .governanceV1:
                return .democracy
            case .governanceV2:
                return .openGov
            }
        }

        static func defaultGovTypeForChain(_ chain: ChainModel) -> GovernanceType? {
            if chain.hasGovernanceV2 {
                return .governanceV2
            } else if chain.hasGovernanceV1 {
                return .governanceV1
            } else {
                return nil
            }
        }
    }

    enum WalletEntity {
        enum QueryKey {
            static let mnemonic = "mnemonic"
            static let type = "cryptotype"
            static let substrateDp = "substratedp"
            static let evmDp = "evmdp"
        }
    }

    enum DAppScreen {
        enum QueryKey {
            static let url = "url"
        }
    }

    enum CardScreen {
        enum QueryKey {
            static let provider = "provider"
        }
    }
}

protocol UniversalLinkFactoryProtocol {
    func createUrl(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL?

    func createUrlForStaking() -> URL?
}
