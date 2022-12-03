import UIKit
import SoraUI

protocol TokensManageTableViewCellDelegate: AnyObject {
    func tokensManageCellDidEdit(_ cell: TokensManageTableViewCell)
    func tokensManageCellDidSwitch(_ cell: TokensManageTableViewCell, isOn: Bool)
}

final class TokensManageTableViewCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 40, height: 40)
    }

    weak var delegate: TokensManageTableViewCellDelegate?

    let iconView = AssetIconView()

    let detailsView: MultiValueView = .create { view in
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueTop.font = .semiBoldBody

        view.valueBottom.textColor = R.color.colorTextSecondary()
        view.valueBottom.font = .regularFootnote

        view.spacing = 0
    }

    let editButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconPencil()!
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none

        setupHandlers()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TokensManageViewModel) {
        let iconColor: UIColor

        if viewModel.isOn {
            iconColor = R.color.colorIconPrimary()!
        } else {
            iconColor = R.color.colorIconSecondary()!
        }

        let imageSettings = ImageViewModelSettings(targetSize: Constants.iconSize, cornerRadius: nil, tintColor: iconColor)

        iconView.bind(viewModel: viewModel.imageViewModel, settings: imageSettings)

        detailsView.valueTop.text = viewModel.symbol
        detailsView.valueTop.textColor = viewModel.isOn ? R.color.colorTextPrimary()! :
            R.color.colorTextSecondary()!

        detailsView.valueBottom.text = viewModel.subtitle

        switchView.setOn(viewModel.isOn, animated: false)
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
        contentView.addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

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

        contentView.addSubview(detailsView)

        detailsView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(8.0)
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
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
