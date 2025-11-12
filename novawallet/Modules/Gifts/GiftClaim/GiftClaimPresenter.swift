import Foundation
import Foundation_iOS

final class GiftClaimPresenter {
    weak var view: GiftClaimViewProtocol?
    let wireframe: GiftClaimWireframeProtocol
    let interactor: GiftClaimInteractorInputProtocol
    let viewModelFactory: GiftClaimViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    var giftDescription: ClaimableGiftDescription?
    var giftedWallet: GiftedWalletType?

    init(
        interactor: GiftClaimInteractorInputProtocol,
        wireframe: GiftClaimWireframeProtocol,
        viewModelFactory: GiftClaimViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: - Private

private extension GiftClaimPresenter {
    func provideViewModel() {
        guard
            let giftDescription,
            let giftedWallet,
            let viewModel = viewModelFactory.createViewModel(
                from: giftDescription,
                giftedWallet: giftedWallet,
                locale: localizationManager.selectedLocale
            )
        else { return }

        view?.didReceive(viewModel: viewModel)
    }

    func provideUnpackingViewModel() {
        guard
            let chainAsset = giftDescription?.chainAsset,
            let viewModel = viewModelFactory.createGiftUnpackingViewModel(for: chainAsset)
        else { return }

        view?.didReceiveUnpacking(viewModel: viewModel)
    }
}

// MARK: - GiftClaimPresenterProtocol

extension GiftClaimPresenter: GiftClaimPresenterProtocol {
    func actionClaim() {
        guard let giftDescription else { return }

        view?.didStartLoading()
        interactor.claimGift(with: giftDescription)
    }

    func actionSelectWallet() {
        guard let giftedWallet, let giftDescription else { return }

        wireframe.showGiftWalletChoose(
            from: view,
            selectedWalletId: giftedWallet.wallet.metaId,
            chain: giftDescription.chainAsset.chain,
            delegate: self,
            filter: GiftWalletListFilter()
        )
    }

    func actionManageWallets() {
        wireframe.showManageWallets(from: view)
    }

    func setup() {
        interactor.setup()
    }

    func endUnpacking() {
        wireframe.complete(
            from: view,
            with: R.string(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).localizable.giftClaimSuccessStatus()
        )
    }
}

// MARK: - GiftClaimInteractorOutputProtocol

extension GiftClaimPresenter: GiftClaimInteractorOutputProtocol {
    func didClaimSuccessfully() {
        view?.didStopLoading()
        provideUnpackingViewModel()
    }

    func didReceive(_ claimSetupResult: GiftClaimInteractor.ClaimSetupResult) {
        giftDescription = claimSetupResult.giftDescription
        giftedWallet = claimSetupResult.giftedWallet

        provideViewModel()
    }

    func didReceive(_ error: any Error) {
        view?.didStopLoading()

        guard let giftClaimError = error as? GiftClaimError else {
            presentRetryableError()

            return
        }

        switch giftClaimError {
        case .claimingAccountNotFound:
            wireframe.present(
                error: giftClaimError,
                from: view,
                locale: localizationManager.selectedLocale
            )
        case .alreadyClaimed:
            let localizedStrings = R.string(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).localizable

            wireframe.showError(
                from: view,
                title: localizedStrings.giftErrorAlreadyClaimedTitle(),
                message: localizedStrings.giftErrorAlreadyClaimedMessage(),
                actionTitle: localizedStrings.commonGotIt()
            )
        default:
            presentRetryableError()
        }
    }

    func presentRetryableError() {
        wireframe.showRetryableError(
            from: view,
            locale: localizationManager.selectedLocale,
            retryAction: { [weak self] in
                self?.actionClaim()
            }
        )
    }
}

// MARK: - WalletsChooseDelegate

extension GiftClaimPresenter: WalletsChooseDelegate {
    func walletChooseDidSelect(item: ManagedMetaAccountModel) {
        wireframe.closeWalletChoose(on: view) { [weak self] in
            self?.interactor.changeWallet(to: item.info)
        }
    }
}
