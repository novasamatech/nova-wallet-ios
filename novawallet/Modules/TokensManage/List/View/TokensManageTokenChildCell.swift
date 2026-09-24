import UIKit

final class TokensManageTokenChildCell: UITableViewCell {
    weak var delegate: TokensManageChildCellDelegate?

    let tokenView = MultichainTokenView()

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupHandlers()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TokensManageChildViewModel) {
        tokenView.bind(
            title: viewModel.title,
            subtitle: viewModel.subtitle,
            imageViewModel: viewModel.imageViewModel,
            isOn: viewModel.isOn
        )

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }
    }
}

// MARK: Private

private extension TokensManageTokenChildCell {
    func setupHandlers() {
        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    func setupLayout() {
        contentView.addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.trailingInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(tokenView)
        tokenView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.leadingInset)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-Constants.contentSpacing)
        }
    }

    @objc func actionSwitch() {
        delegate?.childCellDidSwitch(self, isOn: switchView.isOn)
    }
}

// MARK: Constants

extension TokensManageTokenChildCell {
    enum Constants {
        static let height: CGFloat = 56
        static let leadingInset: CGFloat = 72
        static let trailingInset: CGFloat = 20
        static let contentSpacing: CGFloat = 12
    }
}
