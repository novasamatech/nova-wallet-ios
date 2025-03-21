import Foundation
import BigInt
import Operation_iOS
import SoraFoundation

final class RampAssetOperationPresenter: AssetsSearchPresenter, RampFlowManaging {
    var rampWireframe: RampAssetOperationWireframeProtocol? {
        wireframe as? RampAssetOperationWireframeProtocol
    }

    let selectedAccount: MetaAccountModel
    let rampProvider: RampProviderProtocol

    private let checkResultClosure: RampOperationAvailabilityCheckClosure
    private let rampActionsProviderClosure: RampActionProviderClosure
    private let flowManagingClosure: RampFlowManagingClosure
    private let rampCompletionClosure: RampCompletionClosure

    private var rampActions: [RampAction] = []

    init(
        interactor: AssetsSearchInteractorInputProtocol,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        selectedAccount: MetaAccountModel,
        rampProvider: RampProviderProtocol,
        wireframe: RampAssetOperationWireframeProtocol,
        checkResultClosure: @escaping RampOperationAvailabilityCheckClosure,
        rampActionsProviderClosure: @escaping RampActionProviderClosure,
        flowManagingClosure: @escaping RampFlowManagingClosure,
        rampCompletionClosure: @escaping RampCompletionClosure,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.rampProvider = rampProvider
        self.checkResultClosure = checkResultClosure
        self.rampActionsProviderClosure = rampActionsProviderClosure
        self.flowManagingClosure = flowManagingClosure
        self.rampCompletionClosure = rampCompletionClosure

        super.init(
            delegate: nil,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )
    }

    override func selectGroup(with symbol: AssetModel.Symbol) {
        processGroupSelectionWithCheck(
            symbol,
            onSingleInstance: { chainAsset in
                processAssetSelected(chainAsset)
            },
            onMultipleInstances: { multichainToken in
                rampWireframe?.showSelectNetwork(
                    from: view,
                    multichainToken: multichainToken,
                    selectedAccount: selectedAccount,
                    rampProvider: rampProvider
                )
            }
        )
    }

    override func selectAsset(for chainAssetId: ChainAssetId) {
        guard let chainAsset = result?.state.chainAsset(for: chainAssetId) else {
            return
        }

        processAssetSelected(chainAsset)
    }

    private func processAssetSelected(_ chainAsset: ChainAsset) {
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
            rampWireframe?.presentOperationCompletion(
                on: view,
                by: commonCheckResult,
                successRouteClosure: { [weak self] in
                    guard let self else { return }

                    flowManagingClosure(self)(
                        view,
                        rampActions,
                        rampWireframe,
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

extension RampAssetOperationPresenter: RampDelegate {
    func rampDidComplete() {
        guard let rampWireframe else { return }

        rampCompletionClosure(rampWireframe)(
            view,
            selectedLocale
        )
    }
}
