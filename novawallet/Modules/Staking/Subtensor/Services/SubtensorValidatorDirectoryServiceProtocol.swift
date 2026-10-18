import Foundation
import Operation_iOS

protocol SubtensorValidatorDirectoryServiceProtocol: AnyObject {
    func createDirectoryWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectory>

    func cachedDirectory(for subnet: SubtensorSubnetRef) -> HTTPCachePeek<SubtensorValidatorDirectory>

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem>

    func createListedDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>
}
