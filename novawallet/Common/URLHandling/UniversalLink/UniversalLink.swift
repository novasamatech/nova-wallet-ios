import Foundation

enum UniversalLink {
    enum Screen: String {
        case staking
        case governance = "gov"
        case dApp = "dapp"
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
}
