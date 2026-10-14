import Foundation

final class SubtensorValidatorFiltersInteractor: ValidatorFiltersInteractorProtocol {
    func supported(_ filters: SubtensorValidatorFilters) -> SubtensorValidatorFilters { filters.supported }
}
