import UIKit

struct AnnouncementViewModel: Equatable {
    let style: InlineAlertView.Style
    let message: String
}

protocol AnnouncementViewModelFactoryProtocol {
    func createViewModel(from announcement: Announcement, locale: Locale) -> AnnouncementViewModel?

    func createGeneralViewModels(
        from announcements: [Announcement],
        locale: Locale
    ) -> [AnnouncementViewModel]

    func createChainViewModel(
        from announcements: [Announcement],
        chainId: ChainModel.Id,
        locale: Locale
    ) -> AnnouncementViewModel?
}

final class AnnouncementViewModelFactory: AnnouncementViewModelFactoryProtocol {
    func createViewModel(from announcement: Announcement, locale: Locale) -> AnnouncementViewModel? {
        guard let message = announcement.message(for: locale) else {
            return nil
        }

        return AnnouncementViewModel(
            style: announcement.style.alertStyle,
            message: message
        )
    }

    func createGeneralViewModels(
        from announcements: [Announcement],
        locale: Locale
    ) -> [AnnouncementViewModel] {
        announcements
            .filter { $0.chainId == nil }
            .compactMap { createViewModel(from: $0, locale: locale) }
    }

    func createChainViewModel(
        from announcements: [Announcement],
        chainId: ChainModel.Id,
        locale: Locale
    ) -> AnnouncementViewModel? {
        announcements
            .lazy
            .filter { $0.chainId == chainId }
            .compactMap { self.createViewModel(from: $0, locale: locale) }
            .first
    }
}

extension InlineAlertView {
    func bind(announcement viewModel: AnnouncementViewModel) {
        apply(style: viewModel.style)
        contentView.detailsLabel.text = viewModel.message
    }
}

private extension Announcement.Style {
    var alertStyle: InlineAlertView.Style {
        switch self {
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        }
    }
}
