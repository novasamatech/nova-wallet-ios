import UIKit

final class RequestedAmountRow: RowView<GenericMultiValueView<MultiValueView>> {
    struct Model {
        let title: String
        let amount: MultiValueView.Model
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        preferredHeight = 102
        rowContentView.valueTop.apply(style: .footnoteWhite64)
        rowContentView.valueTop.textAlignment = .left
        rowContentView.valueBottom.apply(style: .accentAmount)
        rowContentView.valueBottom.valueTop.textAlignment = .left
        rowContentView.valueBottom.valueBottom.textAlignment = .left
        roundedBackgroundView.apply(style: .cellWithoutHighlighting)
        contentInsets = .init(top: 16, left: 16, bottom: 16, right: 16)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        borderView.borderType = .none
    }

    func bind(viewModel: Model) {
        rowContentView.valueTop.text = viewModel.title
        rowContentView.valueBottom.bind(viewModel: viewModel.amount)
    }
}
