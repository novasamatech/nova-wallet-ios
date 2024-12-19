import UIKit

final class SwapRouteDetailsView: UIView {
    private var itemListView: UIStackView?
    private var stepsLineView: LinePatternView?
    private var stepViews: [BorderedLabelView] = []

    func bind(viewModel: SwapRouteDetailsViewModel) {
        updateItemsView(for: viewModel)
        updateLineView()
        updateStepViews()
    }
}

private extension SwapRouteDetailsView {
    func updateItemsView(for itemViewModels: SwapRouteDetailsViewModel) {
        itemListView?.removeFromSuperview()

        let itemViews = itemViewModels.map { viewModel in
            let itemView = SwapRouteDetailsItemView()
            itemView.contentView.bind(viewModel: viewModel)
            return itemView
        }

        let itemsView = UIView.vStack(
            alignment: .fill,
            distribution: .fill,
            spacing: 12,
            margins: nil,
            itemViews
        )

        addSubview(itemsView)

        itemsView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().inset(Constants.stepsContainerWidth + Constants.itemsHorOffset)
            make.trailing.equalToSuperview()
        }

        itemListView = itemsView
    }

    func updateLineView() {
        stepsLineView?.removeFromSuperview()
        stepsLineView = nil

        guard
            let items = itemListView?.arrangedSubviews,
            let itemFirst = items.first,
            let itemLast = items.last else {
            return
        }

        let lineView = LinePatternView()
        addSubview(lineView)

        lineView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.width.equalTo(Constants.stepsContainerWidth)
            make.top.equalTo(itemFirst.snp.top).offset(Constants.stepsTopOffset)
            make.bottom.equalTo(itemLast.snp.top).offset(Constants.stepsTopOffset)
        }

        stepsLineView = lineView
    }

    func updateStepViews() {
        stepViews.forEach { $0.removeFromSuperview() }
        stepViews = []

        guard let stepsLineView, let itemListView else { return }

        itemListView.arrangedSubviews.enumerated().forEach { index, itemView in
            let stepView = BorderedLabelView()
            stepView.apply(style: .stepNumber)
            stepView.backgroundView.cornerRadius = Constants.stepWidth / 2
            stepView.titleLabel.text = String(index + 1)
            stepView.titleLabel.textAlignment = .center
            stepView.contentInsets = .zero
            addSubview(stepView)
            stepViews.append(stepView)

            stepView.snp.makeConstraints { make in
                make.centerX.equalTo(stepsLineView)
                make.width.height.equalTo(Constants.stepWidth)
                make.top.equalTo(itemView).offset(Constants.stepsTopOffset)
            }
        }
    }
}

extension SwapRouteDetailsView {
    enum Constants {
        static let stepsContainerWidth: CGFloat = 24
        static let stepWidth: CGFloat = 20
        static let stepsTopOffset: CGFloat = 11
        static let itemsHorOffset: CGFloat = 18
    }
}

typealias SwapRouteDetailsViewModel = [SwapRouteDetailsItemContent.ViewModel]
