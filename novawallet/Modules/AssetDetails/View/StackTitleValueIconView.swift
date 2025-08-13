import Foundation
import UIKit

class StackTitleValueIconView: RowView<
    GenericPairValueView<
        GenericPairValueView<
            UILabel,
            BorderedImageView
        >,
        UILabel
    >
>, StackTableViewCellProtocol {
    var canSelect: Bool = true {
        didSet {
            if oldValue != canSelect {
                updateSelection()
            }
        }
    }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension StackTitleValueIconView {
    func configure() {
        rowContentView.makeVertical()
        rowContentView.spacing = 4
        rowContentView.fView.makeHorizontal()
        rowContentView.fView.spacing = 8.0
    }

    func updateSelection() {
        if canSelect {
            isUserInteractionEnabled = true
            rowContentView.fView.sView.isHidden = false
        } else {
            isUserInteractionEnabled = false
            rowContentView.fView.sView.isHidden = true
        }
    }
}

extension StackTitleValueIconView {
    func bind(with model: BalanceViewModelProtocol) {
        rowContentView.fView.fView.text = model.amount
        rowContentView.sView.text = model.price
    }
}
