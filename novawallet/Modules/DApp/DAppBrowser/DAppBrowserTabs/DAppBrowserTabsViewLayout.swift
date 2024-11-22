import UIKit

final class DAppBrowserTabsViewLayout: UIView {
    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DAppBrowserTabsViewLayout {
    func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }
}
