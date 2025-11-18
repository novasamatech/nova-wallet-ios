import Foundation
import Foundation_iOS

final class GiftPrepareSharePresenter {
    weak var view: GiftPrepareShareViewProtocol?
    let wireframe: GiftPrepareShareWireframeProtocol
    let interactor: GiftPrepareShareInteractorInputProtocol
    let viewModelFactory: GiftPrepareShareViewModelFactoryProtocol

    let localizationManager: LocalizationManagerProtocol

    var chainAsset: ChainAsset?
    var gift: GiftModel?
    var viewModel: GiftPrepareViewModel?

    var flowStyle: GiftPrepareShareViewStyle

    init(
        interactor: GiftPrepareShareInteractorInputProtocol,
        wireframe: GiftPrepareShareWireframeProtocol,
        viewModelFactory: GiftPrepareShareViewModelFactoryProtocol,
        flowStyle: GiftPrepareShareViewStyle,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.flowStyle = flowStyle
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftPrepareSharePresenter {
    func provideViewModel() {
        guard
            let gift,
            let chainAsset,
            let viewModel = viewModelFactory.createViewModel(
                for: chainAsset,
                gift: gift,
                locale: localizationManager.selectedLocale
            )
        else { return }

        view?.didReceive(viewModel: viewModel)
    }

    func presentReclaimRetryable() {
        guard let gift else { return }

        wireframe.showRetryableError(
            from: view,
            locale: localizationManager.selectedLocale,
            retryAction: { [weak self] in self?.interactor.reclaim(gift: gift) }
        )
    }

    func presentReclaimDialog(continueAction: @escaping () -> Void) {
        guard let viewModel else { return }

        let localizedStrings = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable

        let cancelAction = AlertPresentableAction(
            title: localizedStrings.commonCancel(),
            style: .cancel,
            handler: { continueAction() }
        )
        let continueAction = AlertPresentableAction(
            title: localizedStrings.commonContinue(),
            style: .normal,
            handler: { continueAction() }
        )

        let alertViewModel = AlertPresentableViewModel(
            title: localizedStrings.giftReclaimDialogTitle(viewModel.amount),
            message: localizedStrings.giftReclaimDialogMessage(),
            actions: [cancelAction, continueAction],
            closeAction: nil
        )

        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }
}

// MARK: - GiftPrepareSharePresenterProtocol

extension GiftPrepareSharePresenter: GiftPrepareSharePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func actionShare() {
        guard let gift, let chainAsset else { return }

        interactor.share(gift: gift, chainAsset: chainAsset)
    }

    func actionReclaim() {
        guard let gift else { return }

        view?.didReceive(reclaimLoading: true)

        presentReclaimDialog { [weak self] in
            self?.interactor.reclaim(gift: gift)
        }
    }
}

// MARK: - GiftPrepareShareInteractorOutputProtocol

extension GiftPrepareSharePresenter: GiftPrepareShareInteractorOutputProtocol {
    func didReceive(_ data: GiftPrepareShareInteractorOutputData) {
        chainAsset = data.chainAsset
        gift = data.gift

        provideViewModel()
    }

    func didReceive(_ sharingPayload: GiftSharingPayload) {
        guard let gift, let chainAsset else { return }

        let items = viewModelFactory.createShareItems(
            from: sharingPayload,
            gift: gift,
            chainAsset: chainAsset,
            locale: localizationManager.selectedLocale
        )

        wireframe.share(
            items: items,
            from: view,
            with: nil
        )
    }

    func didReceiveClaimSuccess() {
        let successText = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.giftReclaimSuccessStatus()

        wireframe.completeReclaim(
            from: view,
            with: successText
        )
    }

    func didReceive(_ error: Error) {
        view?.didReceive(reclaimLoading: false)

        let localizedStrings = R.string(
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable

        if let giftClaimError = error as? GiftClaimError {
            switch giftClaimError {
            case .alreadyClaimed:
                wireframe.showError(
                    from: view,
                    title: localizedStrings.giftErrorAlreadyClaimedTitle(),
                    message: localizedStrings.giftErrorAlreadyClaimedMessage(),
                    actionTitle: localizedStrings.commonGotIt()
                )
            default:
                if flowStyle == .share {
                    presentReclaimRetryable()
                } else {
                    wireframe.present(
                        error: error,
                        from: view,
                        locale: localizationManager.selectedLocale
                    )
                }
            }
        } else if let giftClaimError = error as? GiftReclaimWalletCheckError {
            guard case let .noAccountForChain(chainId, name) = giftClaimError else {
                presentReclaimRetryable()
                return
            }

            wireframe.showError(
                from: view,
                title: localizedStrings.giftReclaimNoAccountAlertTitle(),
                message: localizedStrings.giftReclaimNoAccountAlertMessage(name),
                actionTitle: localizedStrings.commonGotIt()
            )
        } else if flowStyle == .share {
            presentReclaimRetryable()
        } else {
            wireframe.present(
                error: error,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
