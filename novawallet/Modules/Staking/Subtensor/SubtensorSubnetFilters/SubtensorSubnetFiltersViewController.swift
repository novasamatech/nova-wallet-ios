import UIKit

final class SubtensorSubnetFiltersViewController: UIViewController, ViewHolder {
    typealias RootViewType = SubtensorSubnetFiltersViewLayout

    let presenter: SubtensorSubnetFiltersPresenterProtocol

    private var viewModel: SubtensorSubnetFiltersViewModel?

    init(presenter: SubtensorSubnetFiltersPresenterProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0, height: SubtensorSubnetFiltersViewLayout.contentHeight)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SubtensorSubnetFiltersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()

        presenter.setup()
    }
}

private extension SubtensorSubnetFiltersViewController {
    func setupHandlers() {
        rootView.thinPoolsCell.switchControl.addTarget(
            self,
            action: #selector(actionFilterChanged),
            for: .valueChanged
        )

        rootView.actionButton.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
    }

    @objc func actionFilterChanged() {
        presenter.setHidesThinPools(rootView.thinPoolsCell.switchControl.isOn)
    }

    @objc func actionApply() {
        guard let viewModel, !viewModel.isLoading else {
            return
        }

        view.isUserInteractionEnabled = false

        presenter.apply()
    }
}

extension SubtensorSubnetFiltersViewController: SubtensorSubnetFiltersViewProtocol {
    func didReceive(viewModel: SubtensorSubnetFiltersViewModel) {
        self.viewModel = viewModel

        rootView.bind(viewModel: viewModel)
    }
}
