import Foundation
import Operation_iOS

protocol SubtensorValidatorDirectoryServiceProtocol: AnyObject {
    func createDirectoryWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectory>

    func createDetailWrapper(
        for hotkey: AccountId,
        subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDetail>

    func createPreferredValidatorWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>
}
