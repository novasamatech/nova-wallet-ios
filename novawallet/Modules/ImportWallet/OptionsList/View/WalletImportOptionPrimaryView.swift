import UIKit
import UIKit_iOS

final class WalletImportOptionPrimaryView: RowView<
    GenericPairValueView<WalletImportOptionPrimaryBannerView, MultiValueView>
> {
    var bannerView: UIImageView {
        rowContentView.fView.backgroundImageView
    }

    var imageView: UIImageView {
        rowContentView.fView.mainImageView
    }

    var titleLabel: UILabel {
        rowContentView.sView.valueTop
    }

    var subtitleLabel: UILabel {
        rowContentView.sView.valueBottom
    }

    private var onAction: WalletImportOptionViewModel.RowItem.ActionClosure?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()

        addTarget(self, action: #selector(actionTap), for: .touchUpInside)
    }

    private func setupStyle() {
        contentInsets = .zero

        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        roundedBackgroundView.cornerRadius = 12
        roundedBackgroundView.roundingCorners = .allCorners

        rowContentView.stackView.axis = .vertical
        rowContentView.spacing = 0

        rowContentView.sView.stackView.isLayoutMarginsRelativeArrangement = true
        rowContentView.sView.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        rowContentView.sView.spacing = 8

        titleLabel.apply(style: .semiboldSubhedlinePrimary)
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 0

        subtitleLabel.apply(style: .footnoteSecondary)
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
    }

    func bind(viewModel: WalletImportOptionViewModel.RowItem.Primary) {
        bannerView.image = viewModel.backgroundImage

        rowContentView.fView.bind(mainImage: viewModel.mainImage, position: viewModel.mainImagePosition)

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        onAction = viewModel.onAction
    }

    @objc func actionTap() {
        onAction?()
    }
}

final class WalletImportOptionPrimaryBannerView: UIView {
    let backgroundImageView = UIImageView()
    let mainImageView = UIImageView()

    override var intrinsicContentSize: CGSize {
        let height = backgroundImageView.intrinsicContentSize.height

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupStyle() {
        clipsToBounds = true
        mainImageView.contentMode = .center
    }

    func bind(mainImage: UIImage, position: WalletImportOptionViewModel.RowItem.PrimaryImagePosition) {
        mainImageView.image = mainImage

        switch position {
        case .center:
            mainImageView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
            }
        case .right:
            mainImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview()
            }

        case .bottom:
            mainImageView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        }
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(mainImageView)
        mainImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
