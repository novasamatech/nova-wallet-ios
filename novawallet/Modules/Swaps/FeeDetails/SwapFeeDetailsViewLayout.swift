import UIKit

final class SwapFeeDetailsViewLayout: ScrollableContainerLayoutView {
    let totalFeeView: GenericTitleValueView<UILabel, UILabel> = .create { view in
        view.titleView.apply(style: .semiboldBodyPrimary)
        view.valueView.apply(style: .regularSubhedlinePrimary)
    }

    private var operationFeeViewList: [SwapOperationFeeView] = []

    override func setupStyle() {
        super.setupStyle()

        stackView.layoutMargins = UIEdgeInsets(verticalInset: 0, horizontalInset: 16)
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(totalFeeView, spacingAfter: 8)
        totalFeeView.snp.makeConstraints { make in
            make.height.equalTo(42)
        }
    }

    func bind(viewModel: SwapFeeDetailsViewModel) {
        totalFeeView.valueView.text = viewModel.total

        bindOperationFees(from: viewModel.operationFees)
    }
}

private extension SwapFeeDetailsViewLayout {
    func bindOperationFees(from viewModels: [SwapOperationFeeView.ViewModel]) {
        let itemsToInsert = max(0, viewModels.count - operationFeeViewList.count)
        let itemsToRemove = max(0, operationFeeViewList.count - viewModels.count)

        if itemsToRemove > 0 {
            operationFeeViewList.suffix(itemsToRemove).forEach { $0.removeFromSuperview() }
            operationFeeViewList.removeLast(itemsToRemove)
        }

        if itemsToInsert > 0 {
            (0 ..< itemsToInsert).forEach { _ in
                let feeView = SwapOperationFeeView()
                addArrangedSubview(feeView, spacingAfter: 12)
                operationFeeViewList.append(feeView)
            }
        }

        zip(viewModels, operationFeeViewList).forEach { viewModel, feeView in
            feeView.bind(viewModel: viewModel)
        }
    }
}
