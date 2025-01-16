import UIKit
import UIKit_iOS

final class SwapConfirmViewLayout: ScrollableContainerLayoutView {
    let pairsView = SwapPairView()

    let detailsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
    }

    let rateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let priceDifferenceCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let slippageCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let routeCell: SwapRouteViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let execTimeCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.rowContentView.selectable = false
        $0.isUserInteractionEnabled = false
    }

    let networkFeeCell = SwapNetworkFeeViewCell()

    let walletTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    private var warningView: InlineAlertView?

    let loadableActionView = LoadableActionView()

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()
        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)

        addArrangedSubview(pairsView, spacingAfter: 8)
        addArrangedSubview(detailsTableView, spacingAfter: 8)
        detailsTableView.addArrangedSubview(rateCell)
        detailsTableView.addArrangedSubview(priceDifferenceCell)
        detailsTableView.addArrangedSubview(slippageCell)
        detailsTableView.addArrangedSubview(routeCell)
        detailsTableView.addArrangedSubview(execTimeCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        addArrangedSubview(walletTableView, spacingAfter: 8)
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)

        addSubview(loadableActionView)
        loadableActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + 8
    }

    func setup(locale: Locale) {
        slippageCell.titleButton.setTitle(
            R.string.localizable.swapsSetupSlippage(
                preferredLanguages: locale.rLanguages
            )
        )
        priceDifferenceCell.titleButton.setTitle(
            R.string.localizable.swapsSetupPriceDifference(
                preferredLanguages: locale.rLanguages
            )
        )
        rateCell.titleButton.setTitle(
            R.string.localizable.swapsSetupDetailsRate(
                preferredLanguages: locale.rLanguages
            )
        )
        routeCell.titleButton.setTitle(
            R.string.localizable.swapsDetailsRoute(preferredLanguages: locale.rLanguages)
        )
        execTimeCell.titleButton.setTitle(
            R.string.localizable.swapsDetailsExecTime(preferredLanguages: locale.rLanguages)
        )
        networkFeeCell.titleButton.setTitle(
            R.string.localizable.swapsDetailsTotalFee(preferredLanguages: locale.rLanguages)
        )

        walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: locale.rLanguages)
        accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: locale.rLanguages)

        loadableActionView.actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages)
    }

    func set(warning: String?) {
        applyWarning(
            on: &warningView,
            after: walletTableView,
            text: warning,
            spacing: 8
        )
    }
}
