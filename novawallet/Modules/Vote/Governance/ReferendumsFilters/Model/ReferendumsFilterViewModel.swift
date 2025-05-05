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
                R.string.localizable.governanceReferendumsFilterAll(preferredLanguages: $0.rLanguages)
            }
        case .notVoted:
            return .init {
                R.string.localizable.governanceReferendumsFilterNotVoted(preferredLanguages: $0.rLanguages)
            }
        case .voted:
            return .init {
                R.string.localizable.governanceReferendumsFilterVoted(preferredLanguages: $0.rLanguages)
            }
        }
    }
}
