import UIKit
import SnapKit

final class CrowdloanListViewLayout: UIView {
    private let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorColor = R.color.colorDarkGray()
        view.refreshControl = UIRefreshControl()
        return view
    }()

    let statusView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSeparators(enabled: Bool) {
        tableView.separatorStyle = enabled ? .singleLine : .none
    }

    func setup() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(safeAreaLayoutGuide).inset(64.0)
        }

        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)
        }
    }
}
