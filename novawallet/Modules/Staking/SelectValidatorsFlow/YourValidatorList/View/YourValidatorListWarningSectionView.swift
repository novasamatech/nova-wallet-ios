import UIKit
import SoraUI
import SoraFoundation

class YourValidatorListWarningSectionView: YourValidatorListStatusSectionView {
    let hintView: InlineAlertView = .warning()

    override func setupLayout() {
        super.setupLayout()

        mainStackView.insertArranged(view: hintView, before: statusView)

        mainStackView.setCustomSpacing(20.0, after: hintView)
    }

    func bind(warningText: String) {
        hintView.contentView.detailsLabel.text = warningText
    }
}
