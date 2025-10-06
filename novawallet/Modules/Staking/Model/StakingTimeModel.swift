import Foundation

enum StakingTimeModel {
    case babe(ChainModel)
    case auraGeneral(ChainModel, BlockTimeEstimationServiceProtocol)
    case azero(ChainModel, BlockTimeEstimationServiceProtocol)

    var timelineChain: ChainModel {
        switch self {
        case let .babe(chain):
            return chain
        case let .auraGeneral(chain, _):
            return chain
        case let .azero(chain, _):
            return chain
        }
    }

    var blockTimeService: BlockTimeEstimationServiceProtocol? {
        switch self {
        case .babe:
            return nil
        case let .auraGeneral(_, blockTimeEstimationService):
            return blockTimeEstimationService
        case let .azero(_, blockTimeEstimationService):
            return blockTimeEstimationService
        }
    }
}
