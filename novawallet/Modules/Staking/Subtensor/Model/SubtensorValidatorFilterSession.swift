import Foundation

final class SubtensorValidatorFilterSession {
    private var root = SubtensorValidatorFilters.supportedDefault
    private var subnet = SubtensorValidatorFilters.supportedDefault

    func applied(isRoot: Bool) -> SubtensorValidatorFilters { isRoot ? root : subnet }

    func apply(_ filters: SubtensorValidatorFilters, isRoot: Bool) {
        if isRoot { root = filters.supported } else { subnet = filters.supported }
    }
}
