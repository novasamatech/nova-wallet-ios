import Foundation
import Operation_iOS

extension ParachainStakingCollatorService: StakingCollatorsServiceProtocol {}

typealias ParachainStakingCollatorServiceInterfaces = ParachainStakingCollatorServiceProtocol &
    StakingCollatorsServiceProtocol
