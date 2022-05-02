import UIKit

final class UnknownAddressView: UIView {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let horizontalSpacing: CGFloat = 12.0
    }

    let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        return view
    }()

    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()

    private var iconViewModel: ImageViewModelProtocol?

    override var intrinsicContentSize: CGSize {
        let titleSize = addressLabel.intrinsicContentSize
        let iconSize = Constants.iconSize

        let width = iconSize.width + Constants.horizontalSpacing + titleSize.width

        let height = max(iconSize.height, titleSize.height)

        return CGSize(width: width, height: height)
    }

    convenience init() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 340.0, height: 56.0))
        self.init(frame: defaultFrame)
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

    func bind(address: AccountAddress, iconViewModel: ImageViewModelProtocol?) {
        self.iconViewModel?.cancel(on: iconView)

        self.iconViewModel = iconViewModel

        addressLabel.text = address

        iconViewModel?.loadImage(on: iconView, targetSize: Constants.iconSize, animated: true)

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

        addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView)
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.horizontalSpacing)
            make.trailing.equalToSuperview()
        }
    }
}
