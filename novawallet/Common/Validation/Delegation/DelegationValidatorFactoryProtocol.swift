import Foundation

protocol DelegationValidatorFactoryProtocol: AnyObject {
    var delegationErrorPresentable: DelegationErrorPresentable { get }
    var view: ControllerBackedProtocol? { get }

    func notSelfDelegating(
        selfId: AccountId?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating
}

extension DelegationValidatorFactoryProtocol {
    func notSelfDelegating(
        selfId: AccountId?,
        delegateId: AccountId?,
        locale: Locale?
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak self] in
            guard let view = self?.view else {
                return
            }

            self?.delegationErrorPresentable.presentSelfDelegating(from: view, locale: locale)
        }, preservesCondition: {
            selfId != nil && delegateId != nil && selfId != delegateId
        })
    }
}
