import Foundation
import SoraFoundation

typealias RampOperationAvailabilityCheckClosure = (
    _ rampActions: [RampAction],
    _ walletType: MetaAccountModelType,
    _ chainAsset: ChainAsset
) -> RampAvailableCheckResult

typealias RampActionProviderClosure = (_ rampProvider: RampProviderProtocol) -> (
    _ chainAsset: ChainAsset,
    _ accountId: AccountId
) -> [RampAction]

typealias RampFlowManagingClosure = (
    _ flowManager: RampFlowManaging & RampDelegate
) -> (
    _ view: ControllerBackedProtocol?,
    _ actions: [RampAction],
    _ wireframe: (RampPresentable & AlertPresentable)?,
    _ assetSymbol: AssetModel.Symbol,
    _ locale: Locale
) -> Void

typealias RampCompletionClosure = (_ rampPresentable: RampPresentable) -> (
    _ view: ControllerBackedProtocol?,
    _ locale: Locale
) -> Void

class RampOperationNetworkListPresenter: AssetOperationNetworkListPresenter, RampFlowManaging {
    let selectedAccount: MetaAccountModel

    private let wireframe: RampAssetOperationWireframeProtocol
    private let rampProvider: RampProviderProtocol

    private let checkResultClosure: RampOperationAvailabilityCheckClosure
    private let rampActionsProviderClosure: RampActionProviderClosure
    private let flowManagingClosure: RampFlowManagingClosure
    private let rampCompletionClosure: RampCompletionClosure

    private var rampActions: [RampAction] = []

    init(
        interactor: AssetOperationNetworkListInteractorInputProtocol,
        wireframe: RampAssetOperationWireframeProtocol,
        rampProvider: RampProviderProtocol,
        multichainToken: MultichainToken,
        viewModelFactory: AssetOperationNetworkListViewModelFactory,
        selectedAccount: MetaAccountModel,
        checkResultClosure: @escaping RampOperationAvailabilityCheckClosure,
        rampActionsProviderClosure: @escaping RampActionProviderClosure,
        flowManagingClosure: @escaping RampFlowManagingClosure,
        rampCompletionClosure: @escaping RampCompletionClosure,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.checkResultClosure = checkResultClosure
        self.rampActionsProviderClosure = rampActionsProviderClosure
        self.flowManagingClosure = flowManagingClosure
        self.rampCompletionClosure = rampCompletionClosure
        self.wireframe = wireframe
        self.rampProvider = rampProvider

        super.init(
            interactor: interactor,
            multichainToken: multichainToken,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func provideTitle() {
        let title = R.string.localizable.buyOperationNetworkListTitle(
            multichainToken.symbol,
            preferredLanguages: selectedLocale.rLanguages
        )

        view?.updateHeader(with: title)
    }

    override func selectAsset(with chainAssetId: ChainAssetId) {
        guard let chainAsset = resultModel?.state.chainAsset(for: chainAssetId) else {
            return
        }

        guard let accountId = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        rampActions = rampActionsProviderClosure(rampProvider)(
            chainAsset,
            accountId
        )

        let checkResult = checkResultClosure(
            rampActions,
            selectedAccount.type,
            chainAsset
        )

        switch checkResult {
        case let .common(commonCheckResult):
            wireframe.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    guard let self else { return }

                    flowManagingClosure(self)(
                        view,
                        rampActions,
                        wireframe,
                        chainAsset.asset.symbol,
                        selectedLocale
                    )
                }
            )
        case .noRampOptions:
            break
        }
    }
}

// MARK: RampDelegate

extension RampOperationNetworkListPresenter: RampDelegate {
    func rampDidComplete() {
        rampCompletionClosure(wireframe)(
            view,
            selectedLocale
        )
    }
}
