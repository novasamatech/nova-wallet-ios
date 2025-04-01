import UIKit
import UIKit_iOS

protocol DAppAuthSettingsTableCellDelegate: AnyObject {
    func authSettingsDidSelectCell(_ cell: DAppAuthSettingsTableCell)
}

final class DAppAuthSettingsTableCell: UITableViewCell {
    let iconView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = .zero
        return view
    }()

    weak var delegate: DAppAuthSettingsTableCellDelegate?

    let multiValueView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.textAlignment = .left
        view.valueBottom.textAlignment = .left
        view.valueTop.apply(style: .regularSubhedlinePrimary)
        view.valueBottom.apply(style: .footnoteSecondary)
        view.spacing = 3.0
        return view
    }()

    let removeButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCellClose()
        return button
    }()

    private var viewModel: DAppAuthSettingsViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        setupHandlers()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: DAppAuthSettingsViewModel) {
        iconView.bind(
            viewModel: viewModel.iconViewModel,
            size: DAppIconCellConstants.size
        )

        multiValueView.bind(topValue: viewModel.title, bottomValue: viewModel.subtitle)
    }

    private func setupHandlers() {
        removeButton.addTarget(
            self,
            action: #selector(actionSettings),
            for: .touchUpInside
        )
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(8.0)
            make.size.equalTo(DAppIconCellConstants.size)
        }

        contentView.addSubview(removeButton)
        removeButton.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(60.0)
        }

        contentView.addSubview(multiValueView)
        multiValueView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.trailing.equalTo(removeButton.snp.leading)
        }
    }

    @objc func actionSettings() {
        delegate?.authSettingsDidSelectCell(self)
    }
}
