import UIKit

final class CloudBackupSettingsViewLayout: ScrollableContainerLayoutView {
    let cloudBackupTitleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle3Primary)
    }

    let cloudBackupSubtitleLabel: UILabel = .create { label in
        label.numberOfLines = 0
        label.apply(style: .regularSubhedlineSecondary)
    }

    let cloudBackupActionControl: StackSwitchCell = .create { view in
        view.roundedBackgroundView.roundingCorners = .allCorners
        view.roundedBackgroundView.cornerRadius = 12
        view.roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        view.titleLabel.apply(style: .regularSubhedlinePrimary)
        view.preferredHeight = 52
    }

    let manualBackupTitleLabel: UILabel = .create { label in
        label.apply(style: .boldTitle3Primary)
    }

    let manualBackupSubtitleLabel: UILabel = .create { label in
        label.numberOfLines = 0
        label.apply(style: .regularSubhedlineSecondary)
    }

    let manualBackupActionControl: StackActionCell = .create { view in
        view.rowContentView.iconSize = 0
        view.roundedBackgroundView.roundingCorners = .allCorners
        view.roundedBackgroundView.cornerRadius = 12
        view.roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        view.hasInteractableContent = false
        view.titleLabel.apply(style: .regularSubhedlinePrimary)
        view.preferredHeight = 52
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(cloudBackupTitleLabel, spacingAfter: 8)
        addArrangedSubview(cloudBackupSubtitleLabel, spacingAfter: 16)
        addArrangedSubview(cloudBackupActionControl, spacingAfter: 32)
        addArrangedSubview(manualBackupTitleLabel, spacingAfter: 8)
        addArrangedSubview(manualBackupSubtitleLabel, spacingAfter: 16)
        addArrangedSubview(manualBackupActionControl)
    }
}
