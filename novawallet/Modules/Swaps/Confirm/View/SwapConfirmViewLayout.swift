import UIKit
import SoraUI

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

    private var notificationView: InlineAlertView?

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
    }

    func setup(locale: Locale) {
        slippageCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupSlippage(
            preferredLanguages: locale.rLanguages
        )
        priceDifferenceCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupPriceDifference(
            preferredLanguages: locale.rLanguages
        )
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(
            preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()

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

    func set(notification: String?) {
        applyInfo(
            on: &notificationView,
            after: warningView ?? walletTableView,
            text: notification,
            spacing: 8
        )
    }
}
