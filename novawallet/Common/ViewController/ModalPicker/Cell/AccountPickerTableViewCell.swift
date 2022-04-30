import UIKit
import SubstrateSdk

final class AccountPickerTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = WalletAccountViewModel

    let walletView = WalletAccountView()
    let selectorView = RadioSelectorView()

    var checkmarked: Bool {
        get {
            selectorView.selected
        }

        set {
            selectorView.selected = newValue
        }
    }

    func bind(model: WalletAccountViewModel) {
        walletView.bind(viewModel: model)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccentSelected()!
        self.selectedBackgroundView = selectedBackgroundView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(selectorView)

        let selectorSize = 2 * selectorView.outerRadius

        selectorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(selectorSize)
        }

        contentView.addSubview(walletView)
        walletView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(selectorView.snp.leading).offset(-25.0)
        }
    }
}
