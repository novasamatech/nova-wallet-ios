import Foundation

protocol TableSearchViewProtocol: ControllerBackedProtocol {
    func didStartSearch()
    func didStopSearch()
}

protocol TableSearchPresenterProtocol {
    func setup()
    func search(for textEntry: String)
}
