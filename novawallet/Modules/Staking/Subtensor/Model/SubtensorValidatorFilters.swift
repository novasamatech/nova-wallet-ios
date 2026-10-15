import Foundation

struct SubtensorValidatorFilters: Equatable {
    var sort: SubtensorValidatorSort = .totalStaked
    var hidesUnusualApy = true

    static let supportedDefault = SubtensorValidatorFilters()

    var supported: Self {
        SubtensorValidatorFilters(sort: sort == .apy ? .totalStaked : sort, hidesUnusualApy: hidesUnusualApy)
    }
}
