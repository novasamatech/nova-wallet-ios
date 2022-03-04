import UIKit
import CommonWallet

final class NftDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let mediaView: NftMediaView = {
        let view = NftMediaView()
        view.contentInsets = .zero
        view.contentView.contentMode = .scaleAspectFit
        view.applyFilledBackgroundStyle()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .boldTitle1
        label.numberOfLines = 0
        return label
    }()

    let subtitleView: BorderedLabelView = {
        let view = BorderedLabelView()
        view.titleLabel.textColor = R.color.colorTransparentText()!
        view.titleLabel.font = .semiBoldSmall
        view.contentInsets = UIEdgeInsets(top: 1, left: 6.0, bottom: 2.0, right: 6.0)
        view.backgroundView.cornerRadius = 4.0
        return view
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularSubheadline
        label.numberOfLines = 0
        return label
    }()

    let nftContentView = UIView()

    private(set) var priceView: NftDetailsPriceView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPriceViewIfNeeded() -> NftDetailsPriceView {
        if let priceView = priceView {
            return priceView
        }

        let priceView = NftDetailsPriceView()
        containerView.stackView.insertArranged(view: priceView, after: nftContentView)

        priceView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2.0 * UIConstants.horizontalInset)
        }

        self.priceView = priceView

        return priceView
    }

    func removePriceViewIfNeeded() {
        priceView?.removeFromSuperview()
        priceView = nil
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(mediaView)
        mediaView.snp.makeConstraints { make in
            make.height.equalTo(175.0)
        }

        containerView.stackView.addArrangedSubview(nftContentView)
        nftContentView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(24.0, after: nftContentView)

        nftContentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        nftContentView.addSubview(subtitleView)
        subtitleView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10.0)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
        }

        nftContentView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleView.snp.bottom).offset(18.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(16.0)
        }
    }
}
