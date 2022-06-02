import Foundation
import UIKit

final class StackAccountSelectionCell: RowView<AccountDetailsSelectionView> {
    static let preferredHeight = 48.0

    convenience init() {
        let size = CGSize(width: 340.0, height: Self.preferredHeight)
        let defaultFrame = CGRect(origin: .zero, size: size)
        self.init(frame: defaultFrame)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configureStyle()
    }

    private func configureStyle() {
        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorWhite8()!
        roundedBackgroundView.roundingCorners = .allCorners
        roundedBackgroundView.cornerRadius = 12.0
        borderView.borderType = []

        preferredHeight = Self.preferredHeight

        contentInsets = UIEdgeInsets(top: 7.0, left: 12.0, bottom: 7.0, right: 12.0)
    }

    func bind(viewModel: AccountDetailsSelectionViewModel) {
        rowContentView.bind(viewModel: viewModel)
        invalidateLayout()
    }
}

extension StackAccountSelectionCell: StackTableViewCellProtocol {}
