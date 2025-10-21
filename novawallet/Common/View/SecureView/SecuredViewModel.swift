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

extension SecuredViewModel: Equatable where T: Equatable {
    static func == (
        lhs: SecuredViewModel<T>,
        rhs: SecuredViewModel<T>
    ) -> Bool {
        lhs.originalContent == rhs.originalContent
            && lhs.privacyMode == rhs.privacyMode
    }
}
