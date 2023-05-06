import UIKit

final class SettingsBoxTableViewCell: SettingsAccessoryTableViewCell<BorderedIconLabelView> {
    override func setupStyle() {
        super.setupStyle()

        accessoryDisplayView.backgroundView.apply(style: .chips)
        accessoryDisplayView.backgroundView.cornerRadius = 7
        accessoryDisplayView.iconDetailsView.detailsLabel.numberOfLines = 1
        accessoryDisplayView.iconDetailsView.detailsLabel.apply(style: .footnoteChip)
        accessoryDisplayView.iconDetailsView.iconWidth = 12
        accessoryDisplayView.contentInsets = UIEdgeInsets(
            top: 4,
            left: 8,
            bottom: 4,
            right: 8
        )
        accessoryDisplayView.iconDetailsView.spacing = 4
    }

    func bind(titleViewModel: TitleIconViewModel, accessoryViewModel: TitleIconViewModel) {
        super.bind(titleViewModel: titleViewModel)

        accessoryDisplayView.bind(viewModel: accessoryViewModel)
    }
}
