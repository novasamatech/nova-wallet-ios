import UIKit
import UIKit_iOS

protocol ManageTokenChildItemCellDelegate: AnyObject {
    func childItemCell(_ cell: ManageTokenChildItemCell, didChangeSwitch enabled: Bool)
}

final class ManageTokenChildItemCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 24, height: 24)
    }

    weak var delegate: ManageTokenChildItemCellDelegate?

    let iconImageView = UIImageView()

    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlinePrimary)
    }

    let switchView: UISwitch = .create { view in
        view.onTintColor = R.color.colorIconAccent()
    }

    private var imageViewModel: ImageViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        switchView.setOn(false, animated: false)
        imageViewModel?.cancel(on: iconImageView)
        imageViewModel = nil
    }

    func bind(item: ManageTokenItem) {
        titleLabel.text = item.name

        if item.isEnabled != switchView.isOn {
            switchView.setOn(item.isEnabled, animated: false)
        }

        imageViewModel?.cancel(on: iconImageView)
        imageViewModel = item.icon
        imageViewModel?.loadImage(on: iconImageView, targetSize: Constants.iconSize, animated: true)
    }

    private func setupHandlers() {
        switchView.addTarget(
            self,
            action: #selector(actionSwitch),
            for: .valueChanged
        )
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset + 44)
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
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(switchView.snp.leading).offset(-8)
        }
    }

    @objc private func actionSwitch() {
        delegate?.childItemCell(self, didChangeSwitch: switchView.isOn)
    }
}
