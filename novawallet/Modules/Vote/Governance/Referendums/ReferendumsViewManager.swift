import Foundation
import UIKit

final class ReferendumsViewManager {
    let tableView: UITableView

    var locale = Locale.current

    private weak var parent: ControllerBackedProtocol?

    init(tableView: UITableView, parent: ControllerBackedProtocol) {
        self.tableView = tableView
        self.parent = parent
    }
}

extension ReferendumsViewManager: ReferendumsViewProtocol {}

extension ReferendumsViewManager: VoteChildViewProtocol {
    var isSetup: Bool {
        parent?.isSetup ?? false
    }

    var controller: UIViewController {
        parent?.controller ?? UIViewController()
    }
}
