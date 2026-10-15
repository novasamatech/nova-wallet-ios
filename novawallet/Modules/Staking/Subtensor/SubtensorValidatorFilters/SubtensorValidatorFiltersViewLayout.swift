import UIKit
import UIKit_iOS

final class SubtensorValidatorFiltersViewLayout: UIView {
    let showLabel: UILabel = .create { $0.apply(style: .boldTitle3Primary) }
    let toggleTitle: UILabel = .create { $0.apply(style: .regularBodyPrimary) }
    let toggleSubtitle: UILabel = .create { $0.apply(style: .footnoteSecondary) }
    let toggle: UISwitch = .create { $0.onTintColor = R.color.colorIconAccent() }
    let sortLabel: UILabel = .create { $0.apply(style: .boldTitle3Primary) }
    let tableView: UITableView = .create {
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
        $0.isScrollEnabled = false
        $0.rowHeight = 48
    }

    let bottomPanel = SubtensorBottomPanelView()
    let applyButton: TriangularedButton = .create { $0.applyDefaultStyle() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        let titles = UIView.vStack(alignment: .leading, spacing: 2, [toggleTitle, toggleSubtitle])
        let toggleRow = UIView.hStack(alignment: .center, spacing: 12, [titles, UIView(), toggle])
        let stack = UIView.vStack(spacing: 24, [showLabel, toggleRow, sortLabel, tableView])
        stack.setCustomSpacing(8, after: sortLabel)
        addSubview(stack)
        addSubview(bottomPanel)
        bottomPanel.contentView.addSubview(applyButton)
        stack.snp
            .makeConstraints {
                $0.top.equalTo(safeAreaLayoutGuide).offset(20); $0.leading.trailing.equalToSuperview().inset(16)
            }
        tableView.snp.makeConstraints { $0.height.equalTo(144) }
        bottomPanel.snp.makeConstraints { $0.leading.trailing.bottom.equalToSuperview() }
        applyButton.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(UIConstants.actionHeight)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
