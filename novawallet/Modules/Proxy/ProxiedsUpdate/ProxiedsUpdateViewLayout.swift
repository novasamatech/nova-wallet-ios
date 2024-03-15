import UIKit

final class ProxiedsUpdateViewLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = .zero
        view.rowHeight = UITableView.automaticDimension
        view.allowsSelection = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        view.sectionHeaderHeight = 0
        view.sectionFooterHeight = 0
        view.registerClassForCell(ProxyTableViewCell.self)
        view.registerClassForCell(ProxyInfoTableViewCell.self)
        view.registerHeaderFooterView(withClass: SectionTextHeaderFooterView.self)
        return view
    }()

    let doneButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Constants.titleTopOffset)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Constants.tableTopOffset)
            $0.leading.trailing.equalToSuperview()
        }

        addSubview(doneButton)
        doneButton.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.bottom)
            $0.height.equalTo(UIConstants.actionHeight)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}

extension ProxiedsUpdateViewLayout {
    enum Constants {
        static let titleTopOffset: CGFloat = 10
        static let tableTopOffset: CGFloat = 8
    }
}
