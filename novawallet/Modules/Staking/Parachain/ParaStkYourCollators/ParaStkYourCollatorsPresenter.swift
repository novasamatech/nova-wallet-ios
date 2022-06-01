import Foundation
import SoraFoundation

final class ParaStkYourCollatorsPresenter {
    weak var view: ParaStkYourCollatorsViewProtocol?
    let wireframe: ParaStkYourCollatorsWireframeProtocol
    let interactor: ParaStkYourCollatorsInteractorInputProtocol

    private var collators: Result<[CollatorSelectionInfo], Error>?
    private var delegator: Result<ParachainStaking.Delegator?, Error>?

    let selectedAccount: MetaChainAccountResponse
    let viewModelFactory: ParaStkYourCollatorsViewModelFactoryProtocol

    init(
        interactor: ParaStkYourCollatorsInteractorInputProtocol,
        wireframe: ParaStkYourCollatorsWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        viewModelFactory: ParaStkYourCollatorsViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideViewModel() {
        do {
            guard let collators = try collators?.get(), let delegator = try delegator?.get() else {
                view?.reload(state: .loading)
                return
            }

            let viewModel = try viewModelFactory.createViewModel(
                for: selectedAccount.chainAccount.accountId,
                collators: collators,
                delegator: delegator,
                locale: selectedLocale
            )

            view?.reload(state: .loaded(viewModel: viewModel))

        } catch {
            let errorDescription = R.string.localizable.commonErrorNoDataRetrieved(
                preferredLanguages: selectedLocale.rLanguages
            )

            view?.reload(state: .error(errorDescription))
        }
    }
}

extension ParaStkYourCollatorsPresenter: ParaStkYourCollatorsPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()
    }

    func retry() {
        interactor.retry()
    }

    func manageCollators() {
        let options: [StakingManageOption] = [.stakeMore, .unstake]

        wireframe.showManageCollators(
            from: view,
            options: [.stakeMore, .unstake],
            delegate: self,
            context: options as NSArray
        )
    }

    func selectCollator(viewModel: CollatorSelectionViewModel) {
        guard
            let accountId = try? viewModel.collator.address.toAccountId(),
            let collators = try? collators?.get(),
            let collatorInfo = collators.first(where: { $0.accountId == accountId }) else {
            return
        }

        wireframe.showCollatorInfo(from: view, collatorInfo: collatorInfo)
    }
}

extension ParaStkYourCollatorsPresenter: ParaStkYourCollatorsInteractorOutputProtocol {
    func didReceiveCollators(result: Result<[CollatorSelectionInfo], Error>) {
        collators = result

        provideViewModel()
    }

    func didReceiveDelegator(result: Result<ParachainStaking.Delegator?, Error>) {
        delegator = result

        provideViewModel()
    }
}

extension ParaStkYourCollatorsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let options = context as? [StakingManageOption] else {
            return
        }

        switch options[index] {
        case .stakeMore:
            break
        case .unstake:
            break
        default:
            break
        }
    }
}

extension ParaStkYourCollatorsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
