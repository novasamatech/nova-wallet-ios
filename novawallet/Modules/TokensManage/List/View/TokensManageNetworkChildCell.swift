import UIKit

protocol TokensManageChildCellDelegate: AnyObject {
    func childCellDidSwitch(_ cell: UITableViewCell, isOn: Bool)
}

final class TokensManageNetworkChildCell: UITableViewCell {
    weak var delegate: TokensManageChildCellDelegate?

    let iconView = UIImageView()

    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimary)
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    private var imageViewModel: ImageViewModelProtocol?

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
        titleLabel.text = viewModel.title
        titleLabel.textColor = viewModel.isOn
            ? R.color.colorTextPrimary()
            : R.color.colorTextSecondary()

        iconView.alpha = viewModel.isOn ? 1 : Constants.disabledIconAlpha

        imageViewModel?.cancel(on: iconView)
        imageViewModel = viewModel.imageViewModel
        imageViewModel?.loadImage(
            on: iconView,
            targetSize: Constants.iconSize,
            animated: true
        )

        if viewModel.isOn != switchView.isOn {
            switchView.setOn(viewModel.isOn, animated: false)
        }
    }
}

// MARK: Private

private extension TokensManageNetworkChildCell {
    func setupHandlers() {
        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.leadingInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(switchView)
        switchView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.trailingInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.contentSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-Constants.contentSpacing)
        }
    }

    @objc func actionSwitch() {
        delegate?.childCellDidSwitch(self, isOn: switchView.isOn)
    }
}

// MARK: Constants

extension TokensManageNetworkChildCell {
    enum Constants {
        static let height: CGFloat = 52
        static let leadingInset: CGFloat = 68
        static let trailingInset: CGFloat = 16
        static let contentSpacing: CGFloat = 12
        static let iconSize = CGSize(width: 24, height: 24)
        static let disabledIconAlpha: CGFloat = 0.64
    }
}
