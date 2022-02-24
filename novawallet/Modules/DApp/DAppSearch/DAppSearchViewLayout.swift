import UIKit
import SoraUI

final class DAppSearchViewLayout: UIView {
    let searchBar = DAppSearchBar()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.separatorStyle = .none
        return view
    }()

    let cancelBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tintColor = R.color.colorNovaBlue()
        return item
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
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
