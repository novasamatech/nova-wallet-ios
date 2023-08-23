import UIKit

final class NominationPoolSearchViewLayout: BaseTableSearchViewLayout {
    let loadingView: ListLoadingView = .create {
        $0.isHidden = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        tableView.estimatedRowHeight = 44
        tableView.separatorStyle = .none
    }
}
