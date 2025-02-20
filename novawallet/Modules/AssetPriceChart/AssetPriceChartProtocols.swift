import Foundation
import UIKit

// MARK: Module Interface

typealias AssetPriceChartModule = AssetPriceChartViewProviderProtocol

protocol AssetPriceChartInputOwnerProtocol: AnyObject {
    var assetPriceChartModule: AssetPriceChartModuleInputProtocol? { get set }
}

protocol AssetPriceChartModuleInputProtocol: AnyObject {
    func updateLocale(_ newLocale: Locale)
    func updateSelectedCurrency(_ currency: Currency)
}

protocol AssetPriceChartModuleOutputProtocol: AnyObject {
    func didReceive(_ error: Error)
}

protocol AssetPriceChartViewProviderProtocol: ControllerBackedProtocol {
    func getProposedHeight() -> CGFloat
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
}

protocol AssetPriceChartPresenterProtocol: AnyObject {
    func setup()
    func selectPeriod(_ periodModel: PriceChartPeriod)
}

protocol AssetPriceChartInteractorInputProtocol: AnyObject {
    func setup()
    func updateSelectedCurrency(_ currency: Currency)
}

protocol AssetPriceChartInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(_ error: Error)
}

protocol AssetPriceChartWireframeProtocol: AnyObject {}
