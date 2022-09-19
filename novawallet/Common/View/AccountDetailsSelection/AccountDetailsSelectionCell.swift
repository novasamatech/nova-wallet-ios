import Foundation
import UIKit

typealias AccountDetailsSelectionCell = AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>

final class AccountDetailsGenericSelectionCell<D: AccountDetailsSelectionDecorator>: UITableViewCell,
    ModalPickerCellProtocol {
    typealias Model = SelectableViewModel<AccountDetailsSelectionViewModel>

    var checkmarked: Bool {
        get {
            selectorView.selected
        }

        set {
            selectorView.selected = newValue
        }
    }

    let detailsView: AccountDetailsGenericSelectionView<D> = {
        let view = AccountDetailsGenericSelectionView<D>()
        view.showsDisclosureIndicator = false
        return view
    }()

    let selectorView = RadioSelectorView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: Model) {
        detailsView.bind(viewModel: model.underlyingViewModel, enabled: model.selectable)
    }

    private func setupLayout() {
        let selectorSize = 2 * selectorView.outerRadius

        contentView.addSubview(selectorView)
        selectorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(selectorSize)
        }

        contentView.addSubview(detailsView)
        detailsView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview().inset(9.0)
            make.trailing.equalTo(selectorView.snp.leading).offset(-4.0)
        }
    }
}
