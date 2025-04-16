import Foundation
import Foundation_iOS

final class ParaStkYourCollatorsPresenter {
    weak var view: CollatorStkYourCollatorsViewProtocol?
    let wireframe: ParaStkYourCollatorsWireframeProtocol
    let interactor: ParaStkYourCollatorsInteractorInputProtocol

    private var collators: Result<[ParachainStkCollatorSelectionInfo], Error>?
    private var delegator: Result<ParachainStaking.Delegator?, Error>?
    private var scheduledRequests: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>?

    let selectedAccount: MetaChainAccountResponse
    let viewModelFactory: CollatorStkYourCollatorsViewModelFactory

    init(
        interactor: ParaStkYourCollatorsInteractorInputProtocol,
        wireframe: ParaStkYourCollatorsWireframeProtocol,
        selectedAccount: MetaChainAccountResponse,
        viewModelFactory: CollatorStkYourCollatorsViewModelFactory,
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

            let collatorDelegator = CollatorStakingDelegator(parachainDelegator: delegator)
            let viewModel = try viewModelFactory.createViewModel(
                for: selectedAccount.chainAccount.accountId,
                collators: collators,
                delegator: collatorDelegator,
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

extension ParaStkYourCollatorsPresenter: CollatorStkYourCollatorsPresenterProtocol {
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
        let collators = try? collators?.get()
        let optCollatorInfo = collators?.first { $0.accountId == viewModel.identifier }

        guard let collatorInfo = optCollatorInfo else {
            return
        }

        wireframe.showCollatorInfo(from: view, collatorInfo: collatorInfo)
    }
}

extension ParaStkYourCollatorsPresenter: ParaStkYourCollatorsInteractorOutputProtocol {
    func didReceiveCollators(result: Result<[ParachainStkCollatorSelectionInfo], Error>) {
        collators = result

        provideViewModel()
    }

    func didReceiveDelegator(result: Result<ParachainStaking.Delegator?, Error>) {
        delegator = result

        provideViewModel()
    }

    func didReceiveScheduledRequests(result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>) {
        scheduledRequests = result
    }
}

extension ParaStkYourCollatorsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let options = context as? [StakingManageOption] else {
            return
        }

        let optCollators = try? collators?.get()
        let delegationIdentities = optCollators?.identitiesDict()
        let optDelegator = try? delegator?.get()

        switch options[index] {
        case .stakeMore:
            let scheduledRequests = try? scheduledRequests?.get()
            wireframe.showStakeMore(
                from: view,
                initialDelegator: optDelegator,
                delegationRequests: scheduledRequests,
                delegationIdentities: delegationIdentities
            )
        case .unstake:
            if
                case let .success(optScheduledRequests) = scheduledRequests,
                let disabledCollators = (optScheduledRequests ?? []).map({ Set($0.map(\.collatorId)) }),
                let delegator = optDelegator,
                delegator.delegations.contains(where: { !disabledCollators.contains($0.owner) }) {
                wireframe.showUnstake(
                    from: view,
                    initialDelegator: delegator,
                    delegationRequests: optScheduledRequests,
                    delegationIdentities: delegationIdentities
                )
            } else {
                guard let view = view else {
                    return
                }

                wireframe.presentNoUnstakingOptions(view, locale: selectedLocale)
            }
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
