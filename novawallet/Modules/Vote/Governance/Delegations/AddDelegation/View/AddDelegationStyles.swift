import UIKit_iOS

extension BorderedIconLabelView {
    struct Style {
        let text: UILabel.Style
        let background: RoundedView.Style
    }

    func apply(style: Style) {
        iconDetailsView.detailsLabel.apply(style: style.text)
        backgroundView.apply(style: style.background)
    }
}

extension BorderedIconLabelView.Style {
    static let organization = BorderedIconLabelView.Style(
        text: .init(
            textColor: R.color.colorOrganizationChipText()!,
            font: .semiBoldSmall
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorOrganizationChipBackground()!,
            highlightedFillColor: R.color.colorOrganizationChipBackground()!
        )
    )
    static let individual = BorderedIconLabelView.Style(
        text: .init(
            textColor: R.color.colorIndividualChipText()!,
            font: .semiBoldSmall
        ),
        background: .init(
            shadowOpacity: 0,
            strokeWidth: 0,
            fillColor: R.color.colorIndividualChipBackground()!,
            highlightedFillColor: R.color.colorIndividualChipBackground()!
        )
    )
}
