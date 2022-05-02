import UIKit

final class WalletAccountView: UIView {
    private enum Constants {
        static let walletIconSize = CGSize(width: 32.0, height: 32.0)
        static let addressIconSize = CGSize(width: 18.0, height: 18.0)
        static let walletHorizontalSpacing: CGFloat = 12.0
        static let addressHorizontalSpacing: CGFloat = 4.0
    }

    let walletIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    let walletLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        return label
    }()

    let addressIconView = UIImageView()
    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var viewModel: WalletAccountViewModel?

    override var intrinsicContentSize: CGSize {
        let walletTitleSize = walletLabel.intrinsicContentSize
        let walletIconSize = Constants.walletIconSize
        let addressIconSize = Constants.addressIconSize
        let addressTitleSize = addressLabel.intrinsicContentSize

        let walletWidth = max(
            walletTitleSize.width,
            addressIconSize.width + Constants.addressHorizontalSpacing + addressTitleSize.width
        )

        let width = walletIconSize.width + Constants.walletHorizontalSpacing + walletWidth

        let walletHeight = walletTitleSize.height + max(addressIconSize.height, addressTitleSize.height)

        let height = max(walletIconSize.height, walletHeight)

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

    func bind(viewModel: WalletAccountViewModel) {
        self.viewModel?.walletIcon?.cancel(on: walletIconView)
        self.viewModel?.addressIcon?.cancel(on: addressIconView)

        self.viewModel = viewModel

        walletLabel.text = viewModel.walletName
        addressLabel.text = viewModel.address

        viewModel.walletIcon?.loadImage(on: walletIconView, targetSize: Constants.walletIconSize, animated: true)
        viewModel.addressIcon?.loadImage(on: addressIconView, targetSize: Constants.addressIconSize, animated: true)

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(walletIconView)
        walletIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(Constants.walletIconSize.width)
        }

        addSubview(walletLabel)
        walletLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(walletIconView.snp.trailing).offset(
                Constants.walletHorizontalSpacing
            )
            make.trailing.equalToSuperview()
        }

        addSubview(addressIconView)
        addressIconView.snp.makeConstraints { make in
            make.leading.equalTo(walletLabel)
            make.top.equalTo(walletLabel.snp.bottom)
            make.size.equalTo(Constants.addressIconSize)
            make.bottom.equalToSuperview()
        }

        addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(addressIconView.snp.trailing).offset(
                Constants.addressHorizontalSpacing
            )
            make.centerY.equalTo(addressIconView)
            make.trailing.equalToSuperview()
        }
    }
}
