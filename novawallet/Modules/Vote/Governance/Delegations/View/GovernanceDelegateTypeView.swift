import UIKit

final class GovernanceDelegateTypeView: BorderedIconLabelView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        applyStyle()
    }

    private func applyStyle() {
        iconDetailsView.spacing = 6
        contentInsets = .init(top: 1, left: 4, bottom: 1, right: 6)
        iconDetailsView.detailsLabel.numberOfLines = 1
    }

    func bind(type: GovernanceDelegateTypeView.Model, locale: Locale) {
        switch type {
        case .individual:
            apply(style: .individual)
            let title = R.string.localizable.delegationsShowChipIndividual(
                preferredLanguages: locale.rLanguages
            ).uppercased()
            iconDetailsView.bind(viewModel: .init(
                title: title,
                icon: R.image.iconIndividual()
            ))
        case .organization:
            apply(style: .organization)
            let title = R.string.localizable.delegationsShowChipOrganization(
                preferredLanguages: locale.rLanguages
            ).uppercased()

            iconDetailsView.bind(viewModel: .init(
                title: title,
                icon: R.image.iconOrganization()
            ))
        }
    }
}

extension GovernanceDelegateTypeView {
    enum Model {
        case organization
        case individual
    }
}
