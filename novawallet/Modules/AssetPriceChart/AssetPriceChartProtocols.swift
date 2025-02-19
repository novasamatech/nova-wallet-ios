import Foundation
import UIKit

// MARK: Module Interface

typealias AssetPriceChartModule = AssetPriceChartViewProviderProtocol

protocol AssetPriceChartInputOwnerProtocol: AnyObject {
    var assetPriceChartModule: AssetPriceChartModuleInputProtocol? { get set }
}

protocol AssetPriceChartModuleInputProtocol: AnyObject {
    func updateLocale(_ newLocale: Locale)
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
        view: UIView
    ) {
        guard
            let parentController = parent?.controller,
            let childView = controller.view
        else { return }

        parentController.addChild(controller)
        view.addSubview(childView)

        childView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
}

protocol AssetPriceChartInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AssetPriceChartInteractorOutputProtocol: AnyObject {
    func didReceive(_ error: Error)
}

protocol AssetPriceChartWireframeProtocol: AnyObject {}
