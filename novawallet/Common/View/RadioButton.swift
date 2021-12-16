import UIKit
import SoraUI

class RadioButton<Model>: RoundedButton {
    let model: Model

    init(model: Model) {
        self.model = model
        super.init(frame: .zero)
        setupColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupColors() {
        roundedBackgroundView?.cornerRadius = 12
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorWhite()!.withAlphaComponent(0.16)
        roundedBackgroundView?.highlightedFillColor = R.color.colorWhite()!.withAlphaComponent(0.16)

        contentInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        imageWithTitleView?.titleColor = R.color.colorWhite()
        imageWithTitleView?.highlightedTitleColor = R.color.colorWhite()
        imageWithTitleView?.titleFont = .p0Paragraph
        imageWithTitleView?.layoutType = .horizontalImageFirst
        imageWithTitleView?.iconImage = R.image.iconRadioButtonUnselected()
        imageWithTitleView?.highlightedIconImage = R.image.iconRadioButtonSelected()
    }
}
