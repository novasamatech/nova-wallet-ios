import UIKit

final class ChainAccountAddTableViewCell: ChainAccountTableViewCell {
    func bind(viewModel: ChainAccountAddViewModel) {
        if viewModel.exists {
            chainAccountView.actionIconView.image = R.image.iconDone24()?.tinted(with: R.color.colorIconPositive()!)
        } else {
            chainAccountView.actionIconView.image = R.image.iconBlueAdd()?.tinted(
                with: R.color.colorButtonTextAccent()!
            )
        }

        chainAccountView.bind(viewModel: viewModel.chainAccount)
    }
}
