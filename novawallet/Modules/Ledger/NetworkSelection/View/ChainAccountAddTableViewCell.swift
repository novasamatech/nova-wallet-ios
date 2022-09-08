import UIKit

final class ChainAccountAddTableViewCell: ChainAccountTableViewCell {
    func bind(viewModel: ChainAccountAddViewModel) {
        if viewModel.exists {
            chainAccountView.actionIconView.image = R.image.iconDone24()
        } else {
            chainAccountView.actionIconView.image = R.image.iconBlueAdd()
        }

        chainAccountView.bind(viewModel: viewModel.chainAccount)
    }
}
