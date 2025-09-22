import Foundation

struct SecuredViewModel<T> {
    let originalContent: T
    let privacyMode: ViewPrivacyMode
}

extension SecuredViewModel {
    static func wrapped(_ model: T, with privacyEnabled: Bool) -> Self {
        SecuredViewModel(
            originalContent: model,
            privacyMode: privacyEnabled ? .hidden : .visible
        )
    }
}
