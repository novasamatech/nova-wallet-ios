import UIKit
import UIKit_iOS

final class AssetListMultisigOperationsCell: CollectionViewContainerCell<AssetListMultisigOperationsView> {
    var locale: Locale {
        get { view.locale }
        set { view.locale = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        changesContentOpacityWhenHighlighted = true
    }

    func bind(viewModel: AssetListMultisigOperationsViewModel) {
        view.bind(viewModel: viewModel)
    }
}

final class AssetListMultisigOperationsView: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimary)
    }

    let counterView: RoundedIconTitleView = .create { view in
        view.titleView.imageView.image = R.image.iconPending()
        view.titleView.detailsLabel.apply(style: .semiboldChip)
        view.titleView.spacing = 4.0
        view.roundedBackgroundView.apply(style: .chips)
        view.roundedBackgroundView.cornerRadius = 8.0
    }

    var counterLabel: UILabel {
        counterView.titleView.detailsLabel
    }

    let accessoryImageView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorIconSecondary()!)
    }

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetListMultisigOperationsViewModel) {
        counterLabel.text = viewModel.totalCount
    }
}

// MARK: - Private

private extension AssetListMultisigOperationsView {
    func setupLayout() {
        addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(32.0)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(32.0)
            make.centerY.equalToSuperview()
        }

        addSubview(counterView)
        counterView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
        }
    }

    func setupLocalization() {
        titleLabel.text = R.string.localizable.multisigTransactionsToSign(
            preferredLanguages: locale.rLanguages
        )
    }
}
