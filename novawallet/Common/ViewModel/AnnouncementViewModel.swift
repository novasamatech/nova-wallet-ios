import UIKit

struct AnnouncementLinkViewModel: Equatable {
    let title: String
    let url: URL
}

struct AnnouncementViewModel: Equatable {
    let style: InlineAlertView.Style
    let message: String
    let link: AnnouncementLinkViewModel?
}

protocol AnnouncementViewModelFactoryProtocol {
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
    private func createViewModel(from announcement: Announcement, locale: Locale) -> AnnouncementViewModel? {
        guard let message = announcement.message(for: locale) else {
            return nil
        }

        return AnnouncementViewModel(
            style: announcement.style.alertStyle,
            message: message,
            link: createLinkViewModel(from: announcement.link, locale: locale)
        )
    }

    private func createLinkViewModel(from link: Announcement.Link?, locale: Locale) -> AnnouncementLinkViewModel? {
        guard let link, let title = link.title(for: locale) else {
            return nil
        }

        return AnnouncementLinkViewModel(title: title, url: link.url)
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
    func bind(announcement viewModel: AnnouncementViewModel, includingLink: Bool = true) {
        apply(style: viewModel.style)
        contentView.detailsLabel.text = viewModel.message

        if includingLink, let link = viewModel.link {
            setLink(title: link.title)
        } else {
            setLink(title: nil)
        }
    }

    static func estimatedHeight(
        for viewModel: AnnouncementViewModel,
        width: CGFloat,
        includingLink: Bool = true
    ) -> CGFloat {
        estimatedHeight(
            for: viewModel.message,
            width: width,
            hasLink: includingLink && viewModel.link != nil
        )
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
