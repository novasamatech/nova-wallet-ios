import Foundation

struct SubtensorValidatorRowViewModel {
    let item: SubtensorValidatorDirectoryItem
    let title: String
    let subtitle: String
    let apy: String?
    let isSelected: Bool
}

struct SubtensorValidatorInfoContext {
    let detail: SubtensorValidatorDetail
    let apy: String?
    let locale: Locale
    let chainAsset: ChainAsset
    let price: Balance?
}

enum SubtensorValidatorSort: Equatable {
    case apy
    case totalStaked
    case name
}

protocol SubtensorValidatorSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(rows: [SubtensorValidatorRowViewModel], isLoading: Bool)
    func didReceive(selectionTitle: String?, isEnabled: Bool)
    func didFailDirectory()
}

protocol ValidatorSelectPresenterProtocol: AnyObject {
    func setup()
    func search(_ query: String)
    func selectSort(_ sort: SubtensorValidatorSort)
    func select(at index: Int)
    func showInfo(at index: Int)
    func confirm()
    func retry()
}

protocol ValidatorSelectInteractorInputProtocol: AnyObject {
    func loadDirectory(for subnet: SubtensorSubnetRef)
    func loadYields(for netuid: UInt16)
    func loadDetail(for item: SubtensorValidatorDirectoryItem, subnet: SubtensorSubnetRef)
}

protocol ValidatorSelectInteractorOutputProtocol: AnyObject {
    func didReceive(directory: SubtensorValidatorDirectory)
    func didReceive(yields: SubtensorAlphaYields)
    func didReceive(detail: SubtensorValidatorDetail)
    func didFailDirectory(_ error: Error)
}

protocol ValidatorSelectWireframeProtocol: AnyObject {
    func complete(from view: SubtensorValidatorSelectViewProtocol?)
    func showInfo(from view: SubtensorValidatorSelectViewProtocol?, context: SubtensorValidatorInfoContext)
}
