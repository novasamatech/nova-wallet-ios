import UIKit
import UIKit_iOS

final class SwapConfirmViewLayout: ScrollableContainerLayoutView {
    let pairsView = SwapReviewPairView()

    let detailsTableView = StackTableView.createSwapReviewCard()

    let rateCell = SwapReviewTextCell()

    let slippageCell = SwapReviewTextCell()

    let routeCell: SwapReviewRouteCell = .create {
        $0.showsAccessory = true
    }

    let execTimeCell: SwapReviewTextCell = .create {
        $0.showsInfo = false
        $0.isUserInteractionEnabled = false
    }

    let networkFeeCell: SwapReviewTextCell = .create {
        $0.showsAccessory = true
    }

    let walletTableView = StackTableView.createSwapReviewCard()

    let walletCell: SwapReviewAccountCell = .create {
        $0.isUserInteractionEnabled = false
    }

    let accountCell = SwapReviewAccountCell()

    let commissionLabel: UILabel = .create {
        $0.apply(style: .caption1Secondary)
        $0.textAlignment = .center
        $0.numberOfLines = 0
        $0.isHidden = true
    }

    private var warningView: InlineAlertView?

    let loadableActionView = LoadableActionView()

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = Constants.contentInsets

        addArrangedSubview(pairsView, spacingAfter: Constants.sectionSpacing)

        addArrangedSubview(detailsTableView, spacingAfter: Constants.sectionSpacing)
        detailsTableView.addArrangedSubview(rateCell)
        detailsTableView.addArrangedSubview(slippageCell)
        detailsTableView.addArrangedSubview(routeCell)
        detailsTableView.addArrangedSubview(execTimeCell)
        detailsTableView.addArrangedSubview(networkFeeCell)

        addArrangedSubview(walletTableView, spacingAfter: Constants.sectionSpacing)
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)

        addArrangedSubview(commissionLabel)

        addSubview(loadableActionView)
        loadableActionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        containerView.scrollBottomOffset = safeAreaInsets.bottom + UIConstants.actionBottomInset +
            UIConstants.actionHeight + Constants.sectionSpacing
    }

    func setup(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        rateCell.titleButton.setTitle(strings.swapsSetupDetailsRate())
        slippageCell.titleButton.setTitle(strings.swapsSetupSlippage())
        routeCell.titleButton.setTitle(strings.swapsDetailsRoute())
        execTimeCell.titleButton.setTitle(strings.swapsDetailsExecTime())
        networkFeeCell.titleButton.setTitle(strings.swapsDetailsTotalFee())

        walletCell.titleButton.setTitle(strings.commonWallet())
        accountCell.titleButton.setTitle(strings.commonAccount())

        loadableActionView.actionButton.imageWithTitleView?.title = strings.commonConfirm()
    }

    func set(warning: String?) {
        applyWarning(
            on: &warningView,
            after: walletTableView,
            text: warning,
            spacing: Constants.sectionSpacing
        )
    }

    func set(commissionDisclosure: String?) {
        commissionLabel.text = commissionDisclosure
        commissionLabel.isHidden = commissionDisclosure == nil
    }
}

private extension SwapConfirmViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 4, left: 16, bottom: 0, right: 16)
        static let sectionSpacing: CGFloat = 12
    }
}
