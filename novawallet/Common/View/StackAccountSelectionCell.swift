import Foundation
import UIKit

final class StackAccountSelectionCell: RowView<AccountDetailsSelectionView> {
    func bind(viewModel: AccountDetailsSelectionViewModel) {
        rowContentView.bind(viewModel: viewModel)
        invalidateLayout()
    }
}

extension StackAccountSelectionCell: StackTableViewCellProtocol {}
