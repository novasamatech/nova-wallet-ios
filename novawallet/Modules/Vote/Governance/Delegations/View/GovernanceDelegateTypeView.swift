import UIKit

final class GovernanceDelegateTypeView: BorderedIconLabelView {
    var locale = Locale.current {
        didSet {
            applyLocale()
        }
    }

    private var type: GovernanceDelegateTypeView.Model?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyStyle()
    }

    private func applyStyle() {
        iconDetailsView.spacing = 6
        contentInsets = .init(top: 1, left: 4, bottom: 1, right: 6)
        iconDetailsView.detailsLabel.numberOfLines = 1
        backgroundView.cornerRadius = 5
    }

    func bind(type: GovernanceDelegateTypeView.Model) {
        switch type {
        case .individual:
            apply(style: .individual)
        case .organization:
            apply(style: .organization)
        }

        self.type = type

        applyLocale()
    }

    private func applyLocale() {
        guard let type = type else {
            return
        }

        switch type {
        case .individual:
            let title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.delegationsShowChipIndividual().uppercased()
            iconDetailsView.bind(viewModel: .init(
                title: title,
                icon: R.image.iconIndividual()
            ))
        case .organization:
            let title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.delegationsShowChipOrganization().uppercased()

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
