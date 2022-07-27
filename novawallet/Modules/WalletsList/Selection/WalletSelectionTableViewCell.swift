import Foundation

final class WalletSelectionTableViewCell: WalletsListTableViewCell {
    let selectorView = RadioSelectorView()

    override func bind(viewModel: WalletsListViewModel) {
        super.bind(viewModel: viewModel)

        selectorView.selected = viewModel.isSelected
    }

    override func setupLayout() {
        super.setupLayout()

        let selectorSize = 2 * selectorView.outerRadius

        contentView.addSubview(selectorView)
        selectorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(selectorSize)
            make.leading.equalTo(infoView.snp.trailing).offset(8.0)
        }
    }
}
