import UIKit

final class GovernanceTracksSettingsViewLayout: GovernanceSelectTracksViewLayout {
    var govTitleLabel: UILabel { container.titleLabel }
    var networkView: AssetListChainView { container.networkView }

    let container = NetworkTracksContainerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        contentView.stackView.insertArranged(view: container, after: titleLabel)
        contentView.stackView.setCustomSpacing(27, after: container)

        container.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        proceedButton.isHidden = true
    }
}
