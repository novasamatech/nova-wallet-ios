import UIKit
import Foundation_iOS
import UIKit_iOS

protocol VotesViewProtocol: ControllerBackedProtocol {
    func didReceiveViewModels(_ viewModels: LoadableViewModelState<[VotesViewModel]>)
    func didReceive(title: LocalizableResource<String>)
    func didReceiveEmptyView(title: LocalizableResource<String>)
    func didReceiveRefreshState(isAvailable: Bool)
}

protocol VotesPresenterProtocol: AnyObject {
    func setup()
    func select(viewModel: VotesViewModel)
    func refresh()
}

extension VotesPresenterProtocol {
    func refresh() {}
}
