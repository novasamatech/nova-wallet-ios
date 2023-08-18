import UIKit

final class NominationPoolSearchViewLayout: BaseTableSearchViewLayout {
    let loadingView: ListLoadingView = .create {
        $0.isHidden = true
    }

    let emptyView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        tableView.estimatedRowHeight = 44
        tableView.separatorStyle = .none

        setupEmptyView()
    }

    private func setupEmptyView() {
        super.setupLayout()
        emptyStateContainer.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.bottom.equalToSuperview().inset(291)
            $0.leading.trailing.top.equalToSuperview()
        }
    }
}
