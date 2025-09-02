import UIKit_iOS

final class SwapInfoViewCell: RowView<SwapInfoView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleView }
    var valueLabel: UILabel { rowContentView.valueView }

    func bind(loadableViewModel: LoadableViewModelState<String>) {
        rowContentView.bind(loadableViewModel: loadableViewModel)
    }
}

extension SwapInfoViewCell {
    func bind(attention: AttentionState) {
        switch attention {
        case .high:
            valueLabel.textColor = R.color.colorTextNegative()
        case .medium:
            valueLabel.textColor = R.color.colorTextWarning()
        case .low:
            valueLabel.textColor = R.color.colorTextPrimary()
        }
    }

    func bind(differenceViewModel: LoadableViewModelState<DifferenceViewModel>) {
        switch differenceViewModel {
        case .loading:
            bind(loadableViewModel: .loading)
        case let .cached(value):
            bind(attention: value.attention)
            bind(loadableViewModel: .cached(value: value.details))
        case let .loaded(value):
            bind(attention: value.attention)
            bind(loadableViewModel: .loaded(value: value.details))
        }
    }
}
