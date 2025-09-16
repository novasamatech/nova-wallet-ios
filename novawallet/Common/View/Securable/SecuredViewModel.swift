import Foundation

struct SecuredViewModel<T> {
    let originalContent: T
    let privacyMode: ViewPrivacyMode
}
