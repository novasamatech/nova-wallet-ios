import Foundation

enum SubtensorValidatorSort: Equatable {
    case apy
    case totalStaked
    case name
}

struct SubtensorValidatorRowViewModel: Equatable {
    enum Trailing: Equatable {
        case rate(String)
        case inactive(String)
        case none
    }

    let hotkey: AccountId
    let title: String
    let subtitle: String
    let trailing: Trailing
    let isSelected: Bool
    let isSelectable: Bool
}

struct SubtensorValidatorListViewModel: Equatable {
    let rows: [SubtensorValidatorRowViewModel]
    let countTitle: String
    let sortTitle: String
    let emptyText: String?
    let selectTitle: String
    let canSelect: Bool
}

struct SubtensorValidatorListHeaderViewModel: Equatable {
    let countTitle: String
    let sortTitle: String
    let selectTitle: String
}

struct SubtensorValidatorErrorViewModel: Equatable {
    let title: String
    let details: String
    let retryTitle: String?
    let selectTitle: String
}

enum SubtensorValidatorListState: Equatable {
    case loading(SubtensorValidatorListHeaderViewModel)
    case loaded(SubtensorValidatorListViewModel)
    case failed(SubtensorValidatorErrorViewModel)
}

protocol SubtensorValidatorSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(state: SubtensorValidatorListState)
}

protocol ValidatorSelectPresenterProtocol: AnyObject {
    func setup()
    func search(_ query: String)
    func showSortOptions()
    func select(hotkey: AccountId)
    func showInfo(hotkey: AccountId)
    func confirm()
    func retry()
}

protocol ValidatorSelectInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol ValidatorSelectInteractorOutputProtocol: AnyObject {
    func didReceive(directory: SubtensorValidatorDirectory, clientGates: SubtensorClientGates)
    func didFailDirectory(_ error: Error)
    func didReceive(yields: SubtensorAlphaYields?)
    func didReceive(alphaPrice: Balance?)
}

protocol ValidatorSelectWireframeProtocol: SubtensorValidatorInfoPresentable, SubtensorSortSheetPresentable {
    func complete(from view: SubtensorValidatorSelectViewProtocol?)
}
