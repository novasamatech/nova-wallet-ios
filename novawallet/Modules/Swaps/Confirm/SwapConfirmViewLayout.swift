import UIKit
import SoraUI

final class SwapConfirmViewLayout: ScrollableContainerLayoutView {
    let rateCell: SwapRateView = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleView.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
        $0.addBottomSeparator()
    }

    let networkFeeCell = SwapNetworkFeeView(frame: .zero)

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func setup(locale: Locale) {
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(
            preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetwork(
            preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()
    }
}
