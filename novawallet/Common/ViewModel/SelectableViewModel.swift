import Foundation

struct SelectableViewModel<T> {
    let underlyingViewModel: T
    let selectable: Bool
    let enabled: Bool

    init(underlyingViewModel: T, selectable: Bool) {
        self.underlyingViewModel = underlyingViewModel
        self.selectable = selectable
        enabled = true
    }

    init(underlyingViewModel: T, selectable: Bool, enabled: Bool) {
        self.underlyingViewModel = underlyingViewModel
        self.selectable = selectable
        self.enabled = enabled
    }
}
