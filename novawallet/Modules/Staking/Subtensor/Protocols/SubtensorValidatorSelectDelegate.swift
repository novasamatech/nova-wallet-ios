import Foundation

protocol SubtensorValidatorSelectDelegate: AnyObject {
    func didSelectValidator(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget)
    func didCompleteValidatorSelection(_ validator: SubtensorValidatorDirectoryItem, for target: SubtensorStakeTarget)
}

extension SubtensorValidatorSelectDelegate {
    func didCompleteValidatorSelection(_: SubtensorValidatorDirectoryItem, for _: SubtensorStakeTarget) {}
}
