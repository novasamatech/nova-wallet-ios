import Foundation

final class WalletSelectionTableViewCell: WalletsListTableViewCell<RadioSelectorView> {
    var selectorView: RadioSelectorView { contentDisplayView.valueView }

    override func bind(viewModel: WalletsListViewModel) {
        super.bind(viewModel: viewModel)

        selectorView.selected = viewModel.isSelected
    }

    override func setupLayout() {
        super.setupLayout()

        let selectorSize = 2 * selectorView.outerRadius

        selectorView.snp.makeConstraints { make in
            make.size.equalTo(selectorSize)
        }
    }
}
