import UIKit
import UIKit_iOS

protocol TokensManageTableViewCellDelegate: AnyObject {
    func tokensManageCellDidSwitch(_ cell: TokensManageTableViewCell, isOn: Bool)
}

final class TokensManageTableViewCell: UITableViewCell {
    weak var delegate: TokensManageTableViewCellDelegate?

    let tokenView = MultichainTokenView()

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupHandlers()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TokensManageViewModel) {
        tokenView.bind(
            title: viewModel.symbol,
            subtitle: viewModel.subtitle,
            imageViewModel: viewModel.imageViewModel,
            isOn: viewModel.isOn
        )

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }
    }

    private func setupHandlers() {
        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    private func setupLayout() {
        contentView.addSubview(switchView)

        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(tokenView)

        tokenView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-Constants.contentSpacing)
        }
    }

    @objc func actionSwitch() {
        delegate?.tokensManageCellDidSwitch(self, isOn: switchView.isOn)
    }
}

// MARK: Constants

private extension TokensManageTableViewCell {
    enum Constants {
        static let horizontalInset: CGFloat = 20
        static let contentSpacing: CGFloat = 12
    }
}
