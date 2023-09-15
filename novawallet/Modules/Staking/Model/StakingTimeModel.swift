import Foundation

enum StakingTimeModel {
    case babe
    case auraGeneral(BlockTimeEstimationServiceProtocol)
    case azero(BlockTimeEstimationServiceProtocol)

    var blockTimeService: BlockTimeEstimationServiceProtocol? {
        switch self {
        case .babe:
            return nil
        case let .auraGeneral(blockTimeEstimationService):
            return blockTimeEstimationService
        case let .azero(blockTimeEstimationService):
            return blockTimeEstimationService
        }
    }
}
