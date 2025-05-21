import UIKit

final class PayPageProvider {}

extension PayPageProvider: PageViewProviding {
    func initialPageIndex() -> Int {
        1
    }

    func numberOfPages() -> Int {
        2
    }

    func getPageTitle(at index: Int, locale: Locale) -> String {
        switch index {
        case 0:
            R.string.localizable.paySpendTitle(
                preferredLanguages: locale.rLanguages
            )
        case 1:
            R.string.localizable.payShopTitle(
                preferredLanguages: locale.rLanguages
            )
        default:
            fatalError("Title index \(index) out of bounds \(numberOfPages())")
        }
    }

    func getPageView(at index: Int) -> ControllerBackedProtocol? {
        switch index {
        case 0:
            PaySpendViewFactory.createView()
        case 1:
            PayShopViewFactory.createView()
        default:
            fatalError("View index \(index) out of bounds \(numberOfPages())")
        }
    }
}
