import Foundation

enum SubtensorClaimValidations {
    static func claimNotPending(
        isPending: Bool,
        wireframe: SubtensorClaimErrorPresentable,
        view: ControllerBackedProtocol?,
        locale: Locale
    ) -> DataValidating {
        ErrorConditionViolation(onError: { [weak view] in
            guard let view else {
                return
            }

            wireframe.presentClaimPending(view, locale: locale)
        }, preservesCondition: {
            !isPending
        })
    }
}
