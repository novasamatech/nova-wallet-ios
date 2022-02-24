import UIKit
import SoraUI

final class WalletListNftsCell: UICollectionViewCell {
    let backgroundBlurView: TriangularedBlurView = {
        let view = TriangularedBlurView()
        view.sideLength = 12.0
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
    }()

    let counterLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldFootnote
        return label
    }()

    let counterBackgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite16()!
        view.highlightedFillColor = R.color.colorWhite16()!
        view.cornerRadius = 6.0
        return view
    }()

    let accessoryImageView: UIImageView = {
        let imageView = UIImageView()
        let image = R.image.iconSmallArrow()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorWhite48()!)
        imageView.image = image
        return imageView
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.walletListYourNftsTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: WalletListNftsViewModel) {
        switch viewModel.count {
        case let .cached(value), let .loaded(value):
            counterLabel.text = value
        case .loading:
            counterLabel.text = ""
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        contentView.addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalTo(backgroundBlurView.snp.trailing).offset(-16.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(backgroundBlurView.snp.leading).offset(16.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(counterBackgroundView)
        counterBackgroundView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
        }

        counterBackgroundView.addSubview(counterLabel)
        counterLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(2.0)
            make.leading.trailing.equalToSuperview().inset(8.0)
        }
    }
}
