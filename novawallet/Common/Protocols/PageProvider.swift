import Foundation

protocol PageViewProviding {
    func numberOfPages() -> Int
    func initialPageIndex() -> Int
    func getPageTitle(at index: Int, locale: Locale) -> String
    func getPageView(at index: Int) -> ControllerBackedProtocol?
}
