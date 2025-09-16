import Foundation
import Foundation_iOS

struct ButtonState {
    let title: LocalizableResource<String>
    let enabled: Bool

    static let startState = ButtonState(
        title: LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.transferSetupEnterAmount()
        },
        enabled: false
    )

    static func continueState(enabled: Bool) -> ButtonState {
        .init(
            title: LocalizableResource {
                R.string(preferredLanguages: $0.rLanguages).localizable.commonContinue()
            },
            enabled: enabled
        )
    }
}
