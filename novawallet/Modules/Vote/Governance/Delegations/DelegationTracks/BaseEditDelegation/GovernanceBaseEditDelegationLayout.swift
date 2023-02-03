import UIKit
import SoraUI

class GovernanceBaseEditDelegationLayout: GovernanceSelectTracksViewLayout {
    let descriptionLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    let availabilityView: GenericTitleValueView<UILabel, LinkView> = .create {
        $0.titleView.apply(style: .footnoteSecondary)
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
        contentView.stackView.insertArranged(view: availabilityView, after: descriptionLabel)
    }
}
