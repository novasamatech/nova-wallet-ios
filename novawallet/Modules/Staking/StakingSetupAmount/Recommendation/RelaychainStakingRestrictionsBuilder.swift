import Foundation

protocol RelaychainStakingRestrictionsBuilding: AnyObject {
    var delegate: RelaychainStakingRestrictionsBuilderDelegate? { get set }

    func start()
    func stop()
}

protocol RelaychainStakingRestrictionsBuilderDelegate: AnyObject {
    func restrictionsBuilder(
        _ builder: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    )

    func restrictionsBuilder(
        _ builder: RelaychainStakingRestrictionsBuilding,
        didReceive error: Error
    )
}
