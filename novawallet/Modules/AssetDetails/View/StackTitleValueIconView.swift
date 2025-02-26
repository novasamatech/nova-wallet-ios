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

    private func configure() {
        rowContentView.makeVertical()
        rowContentView.spacing = 4
        rowContentView.fView.makeHorizontal()
        rowContentView.fView.fView.apply(style: .boldTitle2Primary)
        rowContentView.sView.apply(style: .regularSubhedlineSecondary)

        isUserInteractionEnabled = true
    }
}
