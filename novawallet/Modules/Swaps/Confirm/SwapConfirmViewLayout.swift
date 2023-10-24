import UIKit
import SoraUI

final class SwapConfirmViewLayout: ScrollableContainerLayoutView {
    let pairsView = SwapPairView()
    
    let detailsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }
    
    let rateCell: SwapRateView = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleView.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
    }
    
    let priceDifferenceCell: SwapRateView = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleView.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
    }
    
    let slippageCell: SwapRateView = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleView.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
    }

    let networkFeeCell = SwapNetworkFeeView(frame: .zero)

    let walletTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }
    
    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }
    
    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

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
        
        addArrangedSubview(walletTableView)
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func setup(locale: Locale) {
        slippageCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupSlippage(
            preferredLanguages: locale.rLanguages
        )
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(
            preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetwork(
            preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()
        
        walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: locale.rLanguages)
        accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: locale.rLanguages)
        
        actionButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages)
    }
}
