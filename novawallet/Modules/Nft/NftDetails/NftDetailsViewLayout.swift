import UIKit
import CommonWallet
import SnapKit

final class NftDetailsViewLayout: UIView {
    static let mediaPlaceholderHeight: CGFloat = 175.0

    var refreshControl: UIRefreshControl? {
        containerView.scrollView.refreshControl
    }

    let navBarBlurView: UIView = {
        let blurView = TriangularedBlurView()
        blurView.cornerCut = []
        return blurView
    }()

    var navBarBlurViewHeightConstraint: Constraint!

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: false)
        view.stackView.alignment = .center
        view.scrollView.refreshControl = UIRefreshControl()
        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 16.0, right: 0.0)
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

    let stackTableView = StackTableView()

    let ownerCell = StackInfoTableCell()
    let networkCell = StackNetworkCell()

    private(set) var collectionCell: StackTableCell?
    private(set) var issuerCell: StackInfoTableCell?

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

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
        containerView.stackView.setCustomSpacing(12.0, after: priceView)

        priceView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2.0 * UIConstants.horizontalInset)
        }

        self.priceView = priceView

        setupPriceLocalization()

        return priceView
    }

    func setupIssuerViewIfNeeded() -> StackInfoTableCell {
        if let issuerCell = issuerCell {
            return issuerCell
        }

        let issuerCell = StackInfoTableCell()
        stackTableView.insertArranged(view: issuerCell, before: networkCell)
        self.issuerCell = issuerCell

        setupIssuerLocalization()

        return issuerCell
    }

    func setupCollectionViewIfNeeded() -> StackTableCell {
        if let collectionCell = collectionCell {
            return collectionCell
        }

        let collectionCell = StackTableCell()
        stackTableView.insertArranged(view: collectionCell, before: ownerCell)
        self.collectionCell = collectionCell

        setupCollectionLocalization()

        return collectionCell
    }

    func removePriceViewIfNeeded() {
        priceView?.removeFromSuperview()
        priceView = nil
    }

    func removeIssueViewIfNeeded() {
        issuerCell?.removeFromSuperview()
        issuerCell = nil
        stackTableView.updateLayout()
    }

    func removeCollectionViewIfNeeded() {
        collectionCell?.removeFromSuperview()
        collectionCell = nil
        stackTableView.updateLayout()
    }

    func setupMediaContentLayout() {
        mediaView.snp.remakeConstraints { make in
            make.width.equalToSuperview()
        }
    }

    func setupMediaPlaceholderLayout() {
        mediaView.snp.remakeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(Self.mediaPlaceholderHeight)
        }
    }

    private func setupLocalization() {
        setupPriceLocalization()

        ownerCell.titleLabel.text = R.string.localizable.nftOwnerTitle(
            preferredLanguages: locale.rLanguages
        )

        networkCell.titleLabel.text = R.string.localizable.commonNetwork(
            preferredLanguages: locale.rLanguages
        )

        setupIssuerLocalization()
        setupCollectionLocalization()
    }

    private func setupPriceLocalization() {
        priceView?.titleLabel.text = R.string.localizable.commonPrice(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupIssuerLocalization() {
        issuerCell?.titleLabel.text = R.string.localizable.nftIssuerTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupCollectionLocalization() {
        collectionCell?.titleLabel.text = R.string.localizable.nftCollectionTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(mediaView)
        mediaView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(nftContentView)
        nftContentView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(24.0, after: mediaView)

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

        containerView.stackView.addArrangedSubview(stackTableView)
        stackTableView.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-2 * UIConstants.horizontalInset)
        }

        stackTableView.addArrangedSubview(ownerCell)
        stackTableView.addArrangedSubview(networkCell)

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            self.navBarBlurViewHeightConstraint = make.height.equalTo(0).constraint
            self.navBarBlurViewHeightConstraint.activate()
        }
    }
}
