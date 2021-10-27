import UIKit
import SnapKit

final class CrowdloanListViewLayout: UIView {
    private let backgroundView: UIView = UIImageView(image: R.image.backgroundImage())

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorColor = R.color.colorDarkGray()
        view.refreshControl = UIRefreshControl()
        view.tableFooterView = UIView()
        view.separatorStyle = .none
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

    private func setup() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(10)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
        }

//        addSubview(statusView)
//        statusView.snp.makeConstraints { make in
//            make.left.right.equalToSuperview()
//            make.bottom.equalTo(safeAreaLayoutGuide)
//            make.top.equalTo(safeAreaLayoutGuide).inset(64.0)
//        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
