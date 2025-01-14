import Foundation

struct DAppListBannerViewModel {
    let title: String
    let subtitle: String

    let imageViewModel: ImageViewModelProtocol
}

// MARK: Hashable

extension DAppListBannerViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }

    static func == (
        lhs: DAppListBannerViewModel,
        rhs: DAppListBannerViewModel
    ) -> Bool {
        lhs.title == rhs.title
    }
}
