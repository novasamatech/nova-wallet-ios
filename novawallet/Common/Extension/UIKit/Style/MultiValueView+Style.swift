import UIKit

extension MultiValueView {
    struct Style {
        let topLabel: UILabel.Style
        let bottomLabel: UILabel.Style
    }

    func apply(style: Style) {
        valueTop.apply(style: style.topLabel)
        valueBottom.apply(style: style.bottomLabel)
    }
}

extension MultiValueView.Style {
    static let rowContrasted = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .regularFootnote
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextSecondary(),
            font: .caption1
        )
    )

    static let bigRowContrasted = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .regularSubheadline
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextSecondary(),
            font: .regularFootnote
        )
    )

    static let row = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextSecondary(),
            font: .regularFootnote
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextSecondary(),
            font: .caption1
        )
    )

    static let contributionReturnsIn = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .regularSubheadline
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextSecondary(),
            font: .caption1
        )
    )

    static let contributionClamable = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .regularSubheadline
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        )
    )

    static let accentAmount = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .boldTitle1
        ),
        bottomLabel: .init(
            textColor: R.color.colorTextPrimary(),
            font: .regularBody
        )
    )
}
