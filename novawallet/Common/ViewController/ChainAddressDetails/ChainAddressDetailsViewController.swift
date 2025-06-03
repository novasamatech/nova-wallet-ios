import UIKit
import Foundation_iOS

final class ChainAddressDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ChainAddressDetailsViewLayout

    let presenter: ChainAddressDetailsPresenterProtocol

    private var actions: [ChainAddressDetailsViewModel.Action] = []
    private var cells: [StackActionCell] = []
    private var titleViewModel: ChainAddressDetailsViewModel.Title?

    init(presenter: ChainAddressDetailsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ChainAddressDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func replaceCells() {
        cells.forEach { $0.removeFromSuperview() }

        cells = []

        for action in actions {
            let cell = rootView.addAction(for: action.indicator)

            cell.addTarget(self, action: #selector(actionCell(_:)), for: .touchUpInside)

            cells.append(cell)
        }

        updateCells()
    }

    private func updateCells() {
        zip(actions, cells).forEach { actionCell in
            let action = actionCell.0
            let cell = actionCell.1

            cell.bind(
                title: action.title.value(for: selectedLocale),
                icon: action.icon,
                details: nil
            )
        }
    }

    private func setupLocalization() {
        if let titleViewModel {
            rootView.updateTitle(with: titleViewModel, locale: selectedLocale)
        }

        updateCells()
    }

    @objc private func actionCell(_ sender: UIControl) {
        guard
            let cell = sender as? StackActionCell,
            let index = cells.firstIndex(of: cell) else {
            return
        }

        presenter.selectAction(at: index)
    }
}

extension ChainAddressDetailsViewController: ChainAddressDetailsViewProtocol {
    func didReceive(viewModel: ChainAddressDetailsViewModel) {
        titleViewModel = viewModel.title

        rootView.updateTitle(with: viewModel.title, locale: selectedLocale)

        if let addressViewModel = viewModel.address {
            rootView.addressIconView.bind(
                viewModel: addressViewModel.imageViewModel,
                size: ChainAddressDetailsMeasurement.iconSize
            )

            rootView.addressLabel.text = addressViewModel.address.twoLineAddress
        } else {
            rootView.addressIconView.bind(
                viewModel: StaticImageViewModel(image: R.image.iconAddressPlaceholder64()!),
                size: ChainAddressDetailsMeasurement.iconSize
            )

            rootView.addressLabel.text = ""
        }

        actions = viewModel.actions

        replaceCells()
    }
}

extension ChainAddressDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
