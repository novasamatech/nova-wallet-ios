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

    override func setupLayout() {
        super.setupLayout()

        addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }
}
