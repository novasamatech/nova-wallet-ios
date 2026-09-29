import UIKit

struct SubtensorSubnetFiltersViewModel {
    let title: String
    let thinPoolsTitle: String
    let thinPoolsDetails: String
    let aboveAverageTitle: String
    let aboveAverageDetails: String
    let filters: SubtensorSubnetFilters
    let unavailableText: String?
    let actionTitle: String
    let isLoading: Bool
}

final class SubtensorSubnetFiltersSheetController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetFiltersSheetViewLayout

    private var viewModel: SubtensorSubnetFiltersViewModel
    private let onChange: (SubtensorSubnetFilters) -> Void
    private let onApply: (SubtensorSubnetFilters) -> Void

    init(
        viewModel: SubtensorSubnetFiltersViewModel,
        onChange: @escaping (SubtensorSubnetFilters) -> Void,
        onApply: @escaping (SubtensorSubnetFilters) -> Void
    ) {
        self.viewModel = viewModel
        self.onChange = onChange
        self.onApply = onApply

        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0, height: SubtensorSubnetFiltersSheetViewLayout.contentHeight)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorSubnetFiltersSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.bind(viewModel: viewModel)
        setupHandlers()
    }
}

private extension SubtensorSubnetFiltersSheetController {
    func setupHandlers() {
        rootView.thinPoolsCell.switchControl.addTarget(
            self,
            action: #selector(actionFilterChanged),
            for: .valueChanged
        )

        rootView.aboveAverageCell.switchControl.addTarget(
            self,
            action: #selector(actionFilterChanged),
            for: .valueChanged
        )

        rootView.actionButton.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
    }

    @objc func actionFilterChanged() {
        onChange(
            SubtensorSubnetFilters(
                hideThinPools: rootView.thinPoolsCell.switchControl.isOn,
                onlyAboveThirtyDayAverage: rootView.aboveAverageCell.switchControl.isOn
            )
        )
    }

    @objc func actionApply() {
        guard !viewModel.isLoading else {
            return
        }

        let filters = viewModel.filters
        let onApply = onApply

        view.isUserInteractionEnabled = false

        dismiss(animated: true) {
            onApply(filters)
        }
    }
}

extension SubtensorSubnetFiltersSheetController: SubtensorSubnetFiltersViewProtocol {
    func didReceive(viewModel: SubtensorSubnetFiltersViewModel) {
        self.viewModel = viewModel

        if isViewLoaded {
            rootView.bind(viewModel: viewModel)
        }
    }
}
