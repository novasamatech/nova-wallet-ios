import Foundation
import UIKit
import UIKit_iOS

final class StackSignatoryInfoTableView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var rows: [WalletInfoControl] = []

    let tableView: StackTableView = .create { view in
        view.cellHeight = Constants.signatoryCellHeight
        view.hasSeparators = false
    }

    func bind(with models: [WalletInfoView<WalletView>.ViewModel]) {
        rows = models.map { signatory in
            let view = WalletInfoControl()
            view.preferredHeight = Constants.signatoryCellHeight
            view.rowContentView.stackView.spacing = 4.0
            view.bind(viewModel: signatory)

            return view
        }

        tableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

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

extension StackSignatoryInfoTableView {
    enum Constants {
        static let signatoryCellHeight: CGFloat = 48.0
    }
}
