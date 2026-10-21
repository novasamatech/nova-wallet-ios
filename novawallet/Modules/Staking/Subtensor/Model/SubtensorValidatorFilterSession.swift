import Foundation

final class SubtensorValidatorFilterSession {
    private var root = SubtensorValidatorFilters()
    private var subnet = SubtensorValidatorFilters()

    func applied(isRoot: Bool) -> SubtensorValidatorFilters { isRoot ? root : subnet }

    func apply(_ filters: SubtensorValidatorFilters, isRoot: Bool) {
        if isRoot { root = filters } else { subnet = filters }
    }
}
