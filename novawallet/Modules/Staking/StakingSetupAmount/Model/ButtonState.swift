import Foundation
import Foundation_iOS

struct ButtonState {
    let title: LocalizableResource<String>
    let enabled: Bool

    static let startState = ButtonState(
        title: LocalizableResource {
            R.string.localizable.transferSetupEnterAmount(preferredLanguages: $0.rLanguages)
        },
        enabled: false
    )

    static func continueState(enabled: Bool) -> ButtonState {
        .init(
            title: LocalizableResource {
                R.string.localizable.commonContinue(preferredLanguages: $0.rLanguages)
            },
            enabled: enabled
        )
    }
}
