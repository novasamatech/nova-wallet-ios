import UIKit
import UIKit_iOS

final class SwapTokenSelectNetworksViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.textAlignment = .center
    }

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.rowHeight = SwapTokenSelectNetworkCell.Constants.height
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Constants.footerContentHeight, right: 0)
    }

    let footerView: UIView = .create { view in
        view.backgroundColor = R.color.colorBottomSheetBackground()
    }

    let doneButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
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
}

// MARK: Private

private extension SwapTokenSelectNetworksViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.titleTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.listTopInset)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(footerView)
        footerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        footerView.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.buttonTopInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

// MARK: Constants

extension SwapTokenSelectNetworksViewLayout {
    enum Constants {
        static let titleTopInset: CGFloat = 6
        static let listTopInset: CGFloat = 42
        static let buttonTopInset: CGFloat = 12
        static let maxVisibleRows = 6

        static var footerContentHeight: CGFloat {
            buttonTopInset + UIConstants.actionHeight + UIConstants.actionBottomInset
        }

        static func preferredHeight(for rowsCount: Int) -> CGFloat {
            let visibleRows = CGFloat(min(rowsCount, maxVisibleRows))

            return listTopInset + visibleRows * SwapTokenSelectNetworkCell.Constants.height + footerContentHeight
        }
    }
}
