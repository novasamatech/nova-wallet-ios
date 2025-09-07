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
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupSlippage()
        )
        priceDifferenceCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupPriceDifference()
        )
        rateCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDetailsRate()
        )
        routeCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsRoute()
        )
        execTimeCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsExecTime()
        )
        networkFeeCell.titleButton.setTitle(
            R.string(preferredLanguages: locale.rLanguages).localizable.swapsDetailsTotalFee()
        )

        walletCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonWallet()
        accountCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonAccount()

        loadableActionView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.commonConfirm()
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
