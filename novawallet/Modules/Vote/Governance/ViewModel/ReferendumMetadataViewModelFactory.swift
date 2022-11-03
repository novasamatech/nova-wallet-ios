import Foundation
import SoraFoundation

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
        readMoreThreshold: Int?,
        locale: Locale
    ) -> ReferendumDetailsTitleView.Details {
        let title = createTitle(for: referendum, metadata: metadata, locale: locale)
        let description = createDescription(for: referendum, metadata: metadata, locale: locale)

        if let readMoreThreshold = readMoreThreshold, description.count > readMoreThreshold {
            let readMoreDescription = description.convertToReadMore(after: readMoreThreshold)

            return .init(title: title, description: readMoreDescription, shouldReadMore: true)
        } else {
            return .init(title: title, description: description, shouldReadMore: false)
        }
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
        if let title = metadata?.name, !title.isEmpty {
            return title
        } else {
            let index = indexFormatter.value(for: locale).string(from: referendum.index as NSNumber)

            return R.string.localizable.govReferendumTitleFallback(
                index ?? "",
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createDescription(for _: ReferendumLocal, metadata: ReferendumMetadataLocal?, locale: Locale) -> String {
        if let description = metadata?.details, !description.isEmpty {
            return description
        } else {
            return R.string.localizable.govReferendumDescriptionFallback(preferredLanguages: locale.rLanguages)
        }
    }
}
