import UIKit

final class IdentityAccountView: UIView {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let horizontalSpacing: CGFloat = 12.0
    }

    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        return label
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var viewModel: DisplayAddressViewModel?

    override var intrinsicContentSize: CGSize {
        let nameTitleSize = nameLabel.intrinsicContentSize
        let iconSize = Constants.iconSize
        let addressTitleSize = addressLabel.intrinsicContentSize

        let walletWidth = max(nameTitleSize.width, addressTitleSize.width)

        let width = iconSize.width + Constants.horizontalSpacing + walletWidth

        let textHeight = nameTitleSize.height + addressTitleSize.height

        let height = max(iconSize.height, textHeight)

        return CGSize(width: width, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: DisplayAddressViewModel) {
        self.viewModel?.imageViewModel?.cancel(on: iconView)

        self.viewModel = viewModel

        nameLabel.text = viewModel.name
        addressLabel.text = viewModel.address

        viewModel.imageViewModel?.loadImage(on: iconView, targetSize: Constants.iconSize, animated: true)

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(Constants.iconSize.width)
        }

        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(
                Constants.horizontalSpacing
            )
            make.trailing.equalToSuperview()
        }

        addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(
                Constants.horizontalSpacing
            )
            make.top.equalTo(nameLabel.snp.bottom)
            make.trailing.equalToSuperview()
        }
    }
}
