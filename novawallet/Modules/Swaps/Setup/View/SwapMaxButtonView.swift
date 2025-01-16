import UIKit
import UIKit_iOS

typealias SwapSetupTitleButton = ControlView<UIView, GenericPairValueView<UILabel, UILabel>>
final class SwapSetupTitleView: GenericTitleValueView<UILabel, SwapSetupTitleButton> {
    var titleLabel: UILabel { titleView }
    var button: SwapSetupTitleButton { valueView }
    var buttonTitle: UILabel { button.controlContentView.fView }
    var buttonValue: UILabel { button.controlContentView.sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        button.backgroundView?.backgroundColor = .clear
    }

    private func configure() {
        titleView.apply(style: .footnoteSecondary)
        buttonTitle.apply(style: .footnoteAccentText)
        buttonValue.apply(style: .footnotePrimary)
        button.controlContentView.spacing = 4
        button.controlContentView.stackView.axis = .horizontal
        button.contentInsets = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        button.changesContentOpacityWhenHighlighted = true
    }
}

extension SwapSetupTitleView {
    func bind(model: TitleHorizontalMultiValueView.Model) {
        titleView.text = model.title
        buttonTitle.text = model.subtitle
        buttonValue.text = model.value
        button.invalidateLayout()
    }
}
