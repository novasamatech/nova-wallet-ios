import Foundation_iOS

struct ReferendumsFilterViewModel: Equatable {
    var selectedFilter: ReferendumsFilter
    var canReset: Bool
    var canApply: Bool
}

extension ReferendumsFilter {
    var name: LocalizableResource<String> {
        switch self {
        case .all:
            return .init {
                R.string(preferredLanguages: $0.rLanguages).localizable.governanceReferendumsFilterAll()
            }
        case .notVoted:
            return .init {
                R.string(preferredLanguages: $0.rLanguages).localizable.governanceReferendumsFilterNotVoted()
            }
        case .voted:
            return .init {
                R.string(preferredLanguages: $0.rLanguages).localizable.governanceReferendumsFilterVoted()
            }
        }
    }
}
