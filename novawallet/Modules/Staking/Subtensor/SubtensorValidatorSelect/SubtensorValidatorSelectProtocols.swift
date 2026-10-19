import Foundation
import SubstrateSdk

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
    let icon: DrawableIcon?
    let title: String
    let subtitle: String
    let trailing: Trailing
    let isSelected: Bool
    let isSelectable: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hotkey == rhs.hotkey && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle &&
            lhs.trailing == rhs.trailing && lhs.isSelected == rhs.isSelected && lhs.isSelectable == rhs.isSelectable
    }
}

struct SubtensorValidatorFilteredEmptyViewModel: Equatable {
    let message: String
    let actionTitle: String
}

struct SubtensorValidatorListViewModel: Equatable {
    enum Empty: Equatable {
        case text(String)
        case filtered(SubtensorValidatorFilteredEmptyViewModel)
    }

    let rows: [SubtensorValidatorRowViewModel]
    let countTitle: String
    let sortTitle: String
    let empty: Empty?
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

struct SubtensorValidatorSelectSnapshot {
    let directory: HTTPCachePeek<SubtensorValidatorDirectory>
    let yields: HTTPCachePeek<SubtensorAlphaYields>
    let alphaPrice: HTTPCachePeek<Balance?>
}

protocol SubtensorValidatorSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(header: SubtensorValidatorListHeaderViewModel, isFilterActive: Bool)
    func didReceive(state: SubtensorValidatorListState)
}

protocol SubtensorValidatorSelectPresenterProtocol: AnyObject {
    func setup()
    func search(_ query: String)
    func showSortOptions()
    func removeFilters()
    func select(hotkey: AccountId)
    func showInfo(hotkey: AccountId)
    func confirm()
    func retry()
}

protocol SubtensorValidatorSelectInteractorInputProtocol: AnyObject {
    func setup()
    func retry()
}

protocol SubtensorValidatorSelectInteractorOutputProtocol: AnyObject {
    func didReceive(snapshot: SubtensorValidatorSelectSnapshot)
    func didReceive(directory: SubtensorValidatorDirectory)
    func didFailDirectory(_ error: Error)
    func didReceive(yields: SubtensorAlphaYields?)
    func didReceive(alphaPrice: Balance?)
    func didReceive(verification: SubtensorValidatorListVerification)
    func didFailVerification(_ error: Error)
}

protocol SubtensorValidatorSelectWireframeProtocol: SubtensorValidatorInfoPresentable, AlertPresentable {
    func showFilters(
        from view: SubtensorValidatorSelectViewProtocol?,
        applied: SubtensorValidatorFilters,
        delegate: SubtensorValidatorFiltersDelegate
    )
    func complete(from view: SubtensorValidatorSelectViewProtocol?, completion: @escaping () -> Void)
}
