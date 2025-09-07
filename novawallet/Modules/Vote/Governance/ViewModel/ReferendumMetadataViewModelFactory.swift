import Foundation
import Foundation_iOS

protocol ReferendumMetadataViewModelFactoryProtocol {
    func createTitle(
        for referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        locale: Locale
    ) -> String

    func createDescription(
        for referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        locale: Locale
    ) -> String
}

extension ReferendumMetadataViewModelFactoryProtocol {
    func createDetailsViewModel(
        for referendum: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        locale: Locale
    ) -> ReferendumDetailsTitleView.Details {
        let title = createTitle(for: referendum, metadata: metadata, locale: locale)
        let description = createDescription(for: referendum, metadata: metadata, locale: locale)

        return .init(title: title, description: description)
    }
}

final class ReferendumMetadataViewModelFactory {
    let indexFormatter: LocalizableResource<NumberFormatter>

    init(indexFormatter: LocalizableResource<NumberFormatter>) {
        self.indexFormatter = indexFormatter
    }
}

extension ReferendumMetadataViewModelFactory: ReferendumMetadataViewModelFactoryProtocol {
    func createTitle(for referendum: ReferendumLocal, metadata: ReferendumMetadataLocal?, locale: Locale) -> String {
        if let title = metadata?.title, !title.isEmpty {
            return title
        } else {
            let index = indexFormatter.value(for: locale).string(from: referendum.index as NSNumber)

            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.govReferendumTitleFallback(index ?? "")
        }
    }

    func createDescription(
        for _: ReferendumLocal,
        metadata: ReferendumMetadataLocal?,
        locale: Locale
    ) -> String {
        if let description = metadata?.content, !description.isEmpty {
            return description
        } else {
            return R.string(preferredLanguages: locale.rLanguages).localizable.govReferendumDescriptionFallback()
        }
    }
}
