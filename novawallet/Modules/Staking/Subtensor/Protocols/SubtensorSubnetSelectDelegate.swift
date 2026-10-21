import Foundation

protocol SubtensorSubnetSelectDelegate: AnyObject {
    func didSelectStakeTarget(
        _ target: SubtensorStakeTarget,
        validator: SubtensorValidatorDirectoryItem?,
        recommendedHotkey: AccountId?
    )
}
