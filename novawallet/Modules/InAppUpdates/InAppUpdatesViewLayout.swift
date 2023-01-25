import UIKit

final class InAppUpdatesViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        view.registerClassForCell(VersionTableViewCell.self)
        view.registerHeaderFooterView(withClass: GradientBannerHeaderView.self)
        view.rowHeight = UITableView.automaticDimension
        return view
    }()

    let installButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        addSubview(installButton)
        installButton.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.bottom)
            $0.height.equalTo(52)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(safeAreaLayoutGuide)
        }
    }
}
