import Foundation
import UIKit
import UIKit_iOS

final class StackSignatoryCheckmarkTableView: UIView {
    let tableView: StackTableView = .create { view in
        view.cellHeight = Constants.signatoryCellHeight
        view.hasSeparators = true
        view.contentInsets = Constants.contentInsets
    }

    func bind(with model: SignatoryListViewModel) {
        model.items.forEach { signatory in
            let view = WalletInfoCheckmarkControl()
            view.bind(viewModel: signatory)

            view.snp.makeConstraints { make in
                make.height.equalTo(Constants.signatoryCellHeight)
            }

            tableView.addArrangedSubview(view)
        }
    }
}

// MARK: Constants

extension StackSignatoryCheckmarkTableView {
    enum Constants {
        static let signatoryCellHeight: CGFloat = 48.0

        static let contentInsets: UIEdgeInsets = .init(
            top: 4.0,
            left: 16.0,
            bottom: 4.0,
            right: 16.0
        )
    }
}
