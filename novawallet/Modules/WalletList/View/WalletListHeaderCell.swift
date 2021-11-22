import UIKit

final class WalletListHeaderCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let iconButton = UIButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletListHeaderViewModel) {
        titleLabel.text = viewModel.title

        let icon = viewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: 40.0, height: 40.0),
            contentScale: UIScreen.main.scale
        )

        iconButton.setImage(icon, for: .normal)

        switch viewModel.amount {
        case .loading:
            amountLabel.text = ""
        case let .cached(value):
            amountLabel.text = value
        case let .loaded(value):
            amountLabel.text = value
        }
    }

    private func setupLayout() {
        contentView.addSubview(iconButton)
        iconButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(40.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(12.0)
            make.trailing.equalTo(iconButton.snp.leading).offset(-8.0)
        }

        contentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(iconButton.snp.leading).offset(-8.0)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }
}
