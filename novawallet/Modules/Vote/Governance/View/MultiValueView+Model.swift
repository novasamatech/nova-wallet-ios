import UIKit

extension MultiValueView: BindableView {
    struct Model {
        let topValue: String
        let bottomValue: String?
    }

    func bind(viewModel: Model) {
        bind(
            topValue: viewModel.topValue,
            bottomValue: viewModel.bottomValue
        )
    }
}
