import Foundation
import UIKit

enum AssetPriceChartState {
    case loading
    case available
    case unavailable(AssetPriceChartUnavailableReason)
}

enum AssetPriceChartUnavailableReason {
    case noHistory
    case failed
}

enum AssetPriceChartStyle {
    case regular
    case compact
}

// MARK: Module Interface

typealias AssetPriceChartModule = AssetPriceChartViewProviderProtocol

protocol AssetPriceChartInputOwnerProtocol: AnyObject {
    var assetPriceChartModule: AssetPriceChartModuleInputProtocol? { get set }
}

protocol AssetPriceChartModuleInputProtocol: AnyObject {
    func updateLocale(_ newLocale: Locale)
    func updateSelectedCurrency(_ currency: Currency)
    func updateAsset(_ asset: AssetModel?)
    func reload()
}

protocol AssetPriceChartModuleOutputProtocol: AnyObject {
    func didReceiveChartState(_ state: AssetPriceChartState)
    func didSelectChartPeriod(_ period: PriceHistoryPeriod)
}

extension AssetPriceChartModuleOutputProtocol {
    func didSelectChartPeriod(_: PriceHistoryPeriod) {}
}

protocol AssetPriceChartViewProviderProtocol: ControllerBackedProtocol {
    func getProposedHeight() -> CGFloat
}

protocol AssetPriceChartExpansionDelegate: AnyObject {
    func priceChartDidRequestExpansion(_ isExpanded: Bool)
}

protocol AssetPriceChartCompactProviderProtocol: AssetPriceChartViewProviderProtocol {
    var expansionDelegate: AssetPriceChartExpansionDelegate? { get set }

    func setExpansion(isExpanded: Bool, isExpandable: Bool, animated: Bool)
}

extension AssetPriceChartViewProviderProtocol {
    func setupView(
        on parent: ControllerBackedProtocol?,
        view: UIView,
        insets: UIEdgeInsets = .zero
    ) {
        guard
            let parentController = parent?.controller,
            let childView = controller.view
        else { return }

        parentController.addChild(controller)
        view.addSubview(childView)

        childView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(insets)
        }

        controller.didMove(toParent: parentController)
    }
}

// MARK: Inner Interfaces

protocol AssetPriceChartViewProtocol: ControllerBackedProtocol {
    func update(with widgetViewModel: AssetPriceChartWidgetViewModel)
    func update(with priceUpdateViewModel: AssetPriceChartPriceUpdateViewModel)
    func didReceive(chartState: AssetPriceChartState)
    func chartViewWidth() -> CGFloat
}

protocol AssetPriceChartPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(_ periodModel: PriceHistoryPeriod)
    func selectEntry(_ entry: AssetPriceChart.Entry?)
}

protocol AssetPriceChartInteractorInputProtocol: AnyObject {
    func setup()
    func updateSelectedCurrency(_ currency: Currency)
    func updateAsset(_ asset: AssetModel?)
    func reload()
}

protocol AssetPriceChartInteractorOutputProtocol: AnyObject {
    func didReceive(prices: [PriceHistoryPeriod: PriceHistory])
    func didReceive(price: PriceData?)
    func didReceive(_ error: AssetPriceChartInteractorError)
}
