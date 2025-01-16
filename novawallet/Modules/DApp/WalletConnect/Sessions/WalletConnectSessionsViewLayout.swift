import UIKit
import UIKit_iOS

final class WalletConnectSessionsViewLayout: UIView {
    let scanButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.changesContentOpacityWhenHighlighted = true
        button.imageWithTitleView?.iconImage = R.image.iconButtonScan()
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.rowHeight = 64
        return view
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
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(scanButton)
        scanButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        let bottomInset = UIConstants.actionBottomInset + UIConstants.actionHeight + 16.0
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0)
    }
}
