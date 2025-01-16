import UIKit
import UIKit_iOS

protocol TokensManageTableViewCellDelegate: AnyObject {
    func tokensManageCellDidEdit(_ cell: TokensManageTableViewCell)
    func tokensManageCellDidSwitch(_ cell: TokensManageTableViewCell, isOn: Bool)
}

final class TokensManageTableViewCell: UITableViewCell {
    weak var delegate: TokensManageTableViewCellDelegate?

    let tokenView = MultichainTokenView()

    let editButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconPencil()?.tinted(with: R.color.colorIconSecondary()!)!
    }

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
        let tokenViewModel = TokenManageViewModel(
            symbol: viewModel.symbol,
            imageViewModel: viewModel.imageViewModel,
            subtitle: viewModel.subtitle,
            isOn: viewModel.isOn
        )

        tokenView.bind(viewModel: tokenViewModel)

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }
    }

    private func setupHandlers() {
        editButton.addTarget(
            self,
            action: #selector(actionEdit),
            for: .touchUpInside
        )

        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    private func setupLayout() {
        contentView.addSubview(switchView)

        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(editButton)

        editButton.snp.makeConstraints { make in
            make.trailing.equalTo(switchView.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }

        contentView.addSubview(tokenView)

        tokenView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(editButton.snp.leading)
        }
    }

    @objc func actionEdit() {
        delegate?.tokensManageCellDidEdit(self)
    }

    @objc func actionSwitch() {
        delegate?.tokensManageCellDidSwitch(self, isOn: switchView.isOn)
    }
}
