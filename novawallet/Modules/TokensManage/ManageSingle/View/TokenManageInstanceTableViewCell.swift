import UIKit

protocol TokenManageInstanceTableViewCellDelegate: AnyObject {
    func tokenManageInstanceCell(_ cell: TokenManageInstanceTableViewCell, didChangeSwitch enabled: Bool)
}

final class TokenManageInstanceTableViewCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 24.0, height: 24.0)
    }

    weak var delegate: TokenManageInstanceTableViewCellDelegate?

    let iconView = UIImageView()

    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlinePrimary)
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    private var imageViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupHandlers()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: TokenManageNetworkViewModel) {
        titleLabel.text = viewModel.network.name

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }

        imageViewModel?.cancel(on: iconView)
        imageViewModel = viewModel.network.icon
        imageViewModel?.loadImage(on: iconView, targetSize: Constants.iconSize, animated: true)
    }

    private func setupHandlers() {
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

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(switchView.snp.trailing).offset(-8)
        }
    }

    @objc private func actionSwitch() {
        delegate?.tokenManageInstanceCell(self, didChangeSwitch: switchView.isOn)
    }
}
