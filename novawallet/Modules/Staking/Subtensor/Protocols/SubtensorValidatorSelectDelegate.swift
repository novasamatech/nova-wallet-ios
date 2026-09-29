import Foundation

protocol SubtensorValidatorSelectDelegate: AnyObject {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget)
}
