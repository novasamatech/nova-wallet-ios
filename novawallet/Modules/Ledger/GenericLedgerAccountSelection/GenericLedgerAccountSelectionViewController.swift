import UIKit
import Foundation_iOS

final class GenericLedgerAccountSelectionController: UIViewController, ViewHolder {
    typealias RootViewType = GenericLedgerAccountSelectionViewLayout

    let presenter: GenericLedgerAccountSelectionPresenterProtocol

    init(presenter: GenericLedgerAccountSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GenericLedgerAccountSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.loadMoreButton.addTarget(self, action: #selector(actionLoadNext), for: .touchUpInside)
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.ledgerAccountConfirmTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.loadMoreButton.setTitle(
            R.string.localizable.commonLoadMoreAccounts(preferredLanguages: selectedLocale.rLanguages)
        )
    }

    @objc private func actionLoadNext() {
        presenter.loadNext()
    }
}

extension GenericLedgerAccountSelectionController: GenericLedgerAccountSelectionViewProtocol {
    func didClearAccounts() {
        rootView.clearSections()
    }

    func didAddAccount(viewModel: GenericLedgerAccountViewModel) {
        let sectionIndex = rootView.sections.count

        let section = rootView.addAccountSection()

        let headerCell = rootView.addAccountHeader(to: section)

        headerCell.bind(viewModel: .init(details: viewModel.title, imageViewModel: viewModel.icon))

        let headerAction = UIAction { [weak self] _ in
            self?.presenter.selectAccount(in: sectionIndex)
        }

        headerCell.addAction(headerAction, for: .touchUpInside)

        viewModel.addresses.enumerated().forEach { index, addressViewModel in
            let addressCell = rootView.addAddressCell(to: section)

            let addressAction = UIAction { [weak self] _ in
                self?.presenter.selectAddress(in: sectionIndex, at: index)
            }

            addressCell.bind(viewModel: addressViewModel, locale: selectedLocale)

            addressCell.addAction(addressAction, for: .touchUpInside)
        }
    }

    func didStartLoading() {
        rootView.loadMoreView.startLoading()
    }

    func didStopLoading() {
        rootView.loadMoreView.stopLoading()
    }

    func didReceive(warningViewModel: TitleWithSubtitleViewModel, canLoadMore: Bool) {
        rootView.setWarning(with: warningViewModel)
        rootView.loadMoreView.isHidden = !canLoadMore
    }
}

extension GenericLedgerAccountSelectionController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
