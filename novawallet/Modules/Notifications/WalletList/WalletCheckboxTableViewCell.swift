import UIKit

final class WalletCheckboxTableViewCell: WalletsListTableViewCell<WalletView, UIImageView> {
    var checkmarkView: UIImageView { contentDisplayView.valueView }

    override func bind(viewModel: WalletsListViewModel) {
        super.bind(viewModel: viewModel)

        checkmarkView.image = viewModel.isSelected ? R.image.iconCheckbox() : R.image.iconCheckboxEmpty()
    }

    override func setupLayout() {
        super.setupLayout()

        checkmarkView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
