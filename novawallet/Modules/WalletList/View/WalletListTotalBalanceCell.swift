import UIKit
import SoraUI

final class WalletListTotalBalanceCell: UICollectionViewCell {
    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        view.overlayView.highlightedFillColor = R.color.colorAccentSelected()!
        return view
    }()

    let titleView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .detailsIcon

        view.detailsLabel.numberOfLines = 1
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.detailsLabel.font = .regularSubheadline

        view.imageView.image = R.image.iconInfoFilled()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite48()!)
        view.iconWidth = 16.0
        view.spacing = 4.0

        return view
    }()

    let amountLabel: UILabel = {
        let view = UILabel()
        view.textColor = R.color.colorWhite()
        view.font = .boldLargeTitle
        view.textAlignment = .center
        return view
    }()

    let lockedBackgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite16()!
        view.highlightedFillColor = R.color.colorWhite16()!
        view.cornerRadius = 3.0
        return view
    }()

    let lockedView: IconDetailsView = {
        let view = IconDetailsView()
        view.mode = .iconDetails

        view.detailsLabel.numberOfLines = 1
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.detailsLabel.font = .regularFootnote

        view.imageView.image = R.image.iconLock()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite48()!)
        view.iconWidth = 12.0
        view.spacing = 5.0

        return view
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if oldValue != isHighlighted {
                let animated = !isHighlighted
                backgroundBlurView.set(highlighted: isHighlighted, animated: animated)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletListHeaderViewModel) {
        switch viewModel.amount {
        case let .loaded(value), let .cached(value):
            amountLabel.text = value
        case .loading:
            amountLabel.text = ""
        }

        switch viewModel.locked {
        case let .loaded(value), let .cached(value):
            lockedView.detailsLabel.text = value
        case .loading:
            lockedView.detailsLabel.text = ""
        }
    }

    private func setupLocalization() {
        titleView.detailsLabel.text = R.string.localizable.walletTotalBalance(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        contentView.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backgroundBlurView.snp.top).offset(16.0)
        }

        contentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalTo(backgroundBlurView).offset(8.0)
            make.trailing.equalTo(backgroundBlurView).offset(-8.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(lockedBackgroundView)
        lockedBackgroundView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(backgroundBlurView.snp.bottom).offset(-16.0)
        }

        lockedBackgroundView.addSubview(lockedView)
        lockedView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(4.0)
            make.top.bottom.equalToSuperview().inset(1.0)
        }
    }
}
