import Foundation
import UIKit
import UIKit_iOS

final class StackSignatoryCheckmarkTableView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var rows: [WalletInfoCheckmarkControl] = []

    let tableView: StackTableView = .create { view in
        view.cellHeight = Constants.signatoryCellHeight
        view.hasSeparators = false
    }

    func bind(with model: SignatoryListViewModel) {
        rows = model.items.map { signatory in
            let view = WalletInfoCheckmarkControl()
            view.bind(viewModel: signatory)

            return view
        }

        rows.forEach { tableView.addArrangedSubview($0) }
    }

    func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: Constants

extension StackSignatoryCheckmarkTableView {
    enum Constants {
        static let signatoryCellHeight: CGFloat = 48.0

        static let contentInsets: UIEdgeInsets = .init(
            top: .zero,
            left: 16.0,
            bottom: .zero,
            right: 16.0
        )
    }
}
