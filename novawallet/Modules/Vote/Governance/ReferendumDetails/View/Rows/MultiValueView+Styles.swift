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
            textColor: R.color.colorWhite(),
            font: .regularFootnote
        ),
        bottomLabel: .init(
            textColor: R.color.colorWhite64(),
            font: .caption1
        )
    )

    static let accentAmount = MultiValueView.Style(
        topLabel: .init(
            textColor: R.color.colorWhite(),
            font: .boldTitle1
        ),
        bottomLabel: .init(
            textColor: R.color.colorWhite64(),
            font: .regularBody
        )
    )
}
