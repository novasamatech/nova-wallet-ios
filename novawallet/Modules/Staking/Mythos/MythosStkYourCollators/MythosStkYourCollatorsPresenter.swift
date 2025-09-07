import Foundation
import Foundation_iOS

final class MythosStkYourCollatorsPresenter {
    weak var view: CollatorStkYourCollatorsViewProtocol?
    let wireframe: MythosStkYourCollatorsWireframeProtocol
    let interactor: MythosStkYourCollatorsInteractorInputProtocol

    private var collators: [CollatorStakingSelectionInfoProtocol]?
    private var stakingDetails: MythosStakingDetails?

    let selectedAccount: MetaChainAccountResponse
    let viewModelFactory: CollatorStkYourCollatorsViewModelFactory
    let logger: LoggerProtocol

    init(
        interactor: MythosStkYourCollatorsInteractorInputProtocol,
        wireframe: MythosStkYourCollatorsWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        viewModelFactory: CollatorStkYourCollatorsViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedAccount = selectedAccount
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension MythosStkYourCollatorsPresenter {
    func provideViewModel() {
        do {
            guard let collators, let stakingDetails else {
                view?.reload(state: .loading)
                return
            }

            let collatorDelegator = CollatorStakingDelegator(mythosDelegator: stakingDetails)
            let viewModel = try viewModelFactory.createViewModel(
                for: selectedAccount.chainAccount.accountId,
                collators: collators,
                delegator: collatorDelegator,
                locale: selectedLocale
            )

            view?.reload(state: .loaded(viewModel: viewModel))

        } catch {
            let errorDescription = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonErrorNoDataRetrieved()

            view?.reload(state: .error(errorDescription))
        }
    }
}

extension MythosStkYourCollatorsPresenter: CollatorStkYourCollatorsPresenterProtocol {
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
            options: options,
            delegate: self,
            context: options as NSArray
        )
    }

    func selectCollator(viewModel: CollatorSelectionViewModel) {
        let optCollatorInfo = collators?.first { $0.accountId == viewModel.identifier }

        guard let collatorInfo = optCollatorInfo else {
            return
        }

        wireframe.showCollatorInfo(from: view, collatorInfo: collatorInfo)
    }
}

extension MythosStkYourCollatorsPresenter: MythosStkYourCollatorsInteractorOutputProtocol {
    func didReceiveStakingDetails(_ details: MythosStakingDetails?) {
        logger.debug("Details: \(String(describing: details))")

        stakingDetails = details

        provideViewModel()
    }

    func didReceiveCollatorsResult(_ result: Result<[CollatorStakingSelectionInfoProtocol], Error>) {
        switch result {
        case let .success(collators):
            logger.debug("Collators: \(collators)")

            self.collators = collators

            provideViewModel()
        case let .failure(error):
            logger.debug("Collators error: \(error)")

            collators = nil

            let errorDescription = R.string(preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonErrorNoDataRetrieved()

            view?.reload(state: .error(errorDescription))
        }
    }
}

extension MythosStkYourCollatorsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let options = context as? [StakingManageOption] else {
            return
        }

        switch options[index] {
        case .stakeMore:
            wireframe.showStakeMore(from: view, initialDetails: stakingDetails)
        case .unstake:
            wireframe.showUnstake(from: view)
        default:
            break
        }
    }
}

extension MythosStkYourCollatorsPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideViewModel()
        }
    }
}
