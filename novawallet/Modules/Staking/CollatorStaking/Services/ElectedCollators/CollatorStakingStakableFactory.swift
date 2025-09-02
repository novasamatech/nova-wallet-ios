import Foundation
import Operation_iOS

protocol CollatorStakingStakableFactoryProtocol {
    func stakableCollatorsWrapper() -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]>
}
