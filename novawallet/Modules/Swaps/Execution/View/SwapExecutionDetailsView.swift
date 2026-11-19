import UIKit
import UIKit_iOS

final class SwapExecutionDetailsView: UIView {
    let tableView = StackTableView.createSwapReviewCard()

    let rateCell: SwapReviewTextCell = .create {
        $0.showsInfo = false
        $0.isUserInteractionEnabled = false
    }

    let routeCell: SwapReviewRouteCell = .create {
        $0.showsInfo = false
        $0.showsAccessory = true
    }

    let totalFeeCell: SwapReviewTextCell = .create {
        $0.showsInfo = false
        $0.isUserInteractionEnabled = false
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        tableView.addArrangedSubview(rateCell)
        tableView.addArrangedSubview(routeCell)
        tableView.addArrangedSubview(totalFeeCell)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        rateCell.titleButton.setTitle(strings.swapsSetupDetailsRate())
        routeCell.titleButton.setTitle(strings.swapsDetailsRoute())
        totalFeeCell.titleButton.setTitle(strings.swapsDetailsTotalFee())
    }
}
