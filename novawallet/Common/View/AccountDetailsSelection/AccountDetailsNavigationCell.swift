import Foundation
import UIKit

typealias AccountDetailsNavigationCell = AccountDetailsGenericNavigationCell<AccountDetailsBalanceDecorator>

final class AccountDetailsGenericNavigationCell<D: AccountDetailsSelectionDecorator>: UITableViewCell,
    ModalPickerCellProtocol {
    typealias Model = AccountDetailsSelectionViewModel

    var checkmarked: Bool = false

    let detailsView = AccountDetailsGenericSelectionView<D>()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorAccentSelected()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: Model) {
        detailsView.bind(viewModel: model, enabled: true)
    }

    private func setupLayout() {
        contentView.addSubview(detailsView)
        detailsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(9.0)
        }
    }
}
