import UIKit

final class WalletListAccountCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldTitle3
        label.textColor = R.color.colorWhite()
        return label
    }()

    let iconButton = UIButton()

    override init(frame: CGRect) {
        super.init(frame: frame)

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
    }

    private func setupLayout() {
        contentView.addSubview(iconButton)
        iconButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(40.0)
            make.top.equalToSuperview().inset(10.0)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(iconButton)
            make.trailing.equalTo(iconButton.snp.leading).offset(-8.0)
        }
    }
}
