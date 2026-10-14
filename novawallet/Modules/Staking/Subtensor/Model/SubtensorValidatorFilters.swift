import Foundation

struct SubtensorValidatorFilters: Equatable {
    var sort: SubtensorValidatorSort = .totalStaked
    var hidesUnusualApy = false

    static let supportedDefault = SubtensorValidatorFilters()

    var supported: Self {
        SubtensorValidatorFilters(sort: sort == .apy ? .totalStaked : sort, hidesUnusualApy: false)
    }
}
