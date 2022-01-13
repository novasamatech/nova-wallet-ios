import UIKit
import SoraUI

final class DAppSearchViewLayout: UIView {
    let searchBar = DAppSearchBar()

    let tableView: UITableView = {
        let view = UITableView()
        view.contentInsetAdjustmentBehavior = .always
        view.separatorStyle = .none
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
