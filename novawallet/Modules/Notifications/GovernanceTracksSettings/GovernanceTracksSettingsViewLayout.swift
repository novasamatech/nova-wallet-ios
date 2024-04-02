import UIKit

final class GovernanceTracksSettingsViewLayout: GovernanceSelectTracksViewLayout {
    let tracksView = NetworkTracksContainerView()

    override func setupLayout() {
        super.setupLayout()

        contentView.stackView.insertArranged(view: tracksView, after: titleLabel)
        contentView.stackView.setCustomSpacing(27, after: tracksView)

        tracksView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        proceedButton.isHidden = true
    }
}
