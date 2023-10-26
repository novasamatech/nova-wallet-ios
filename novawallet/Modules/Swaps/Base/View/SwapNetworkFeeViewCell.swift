import SoraUI

final class SwapNetworkFeeViewCell: RowView<SwapNetworkFeeView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleView }
    var valueTopButton: RoundedButton { rowContentView.valueView.fView }
    var valueBottomLabel: UILabel { rowContentView.valueView.sView }

    func bind(loadableViewModel: LoadableViewModelState<SwapFeeViewModel>) {
        rowContentView.bind(loadableViewModel: loadableViewModel)
    }
}
