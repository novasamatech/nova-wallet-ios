import UIKit
import UIKit_iOS

class GovernanceBaseEditDelegationLayout: GovernanceSelectTracksViewLayout {
    let descriptionLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    let availabilityView: GenericTitleValueView<UILabel, LinkView> = .create {
        $0.titleView.apply(style: .footnoteSecondary)
        $0.valueView.isHidden = true
    }

    var availableTracksLabel: UILabel {
        availabilityView.titleView
    }

    var unavailableTracksView: LinkView {
        availabilityView.valueView
    }

    var unavailableTracksButton: RoundedButton {
        availabilityView.valueView.actionButton
    }

    override func setupLayout() {
        super.setupLayout()

        contentView.stackView.insertArranged(view: descriptionLabel, after: titleLabel)
        contentView.stackView.setCustomSpacing(8, after: descriptionLabel)
        contentView.stackView.setCustomSpacing(8, after: titleLabel)

        descriptionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        contentView.stackView.insertArranged(view: availabilityView, after: descriptionLabel)
        contentView.stackView.setCustomSpacing(8, after: availabilityView)

        availabilityView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(32)
        }
    }
}
