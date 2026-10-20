import Foundation
import NovaAnalytics

extension FeatureSupportChecking where Self: MessageSheetPresentable {
    func checkingSubtensorStakingSupport(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        sheetPresentingView: ControllerBackedProtocol?,
        onRefusal: @escaping (StakingBlockedReason) -> Void,
        successClosure: @escaping () -> Void
    ) {
        guard let sheetPresentingView else { return }

        featureSupportChecker.checkSubtensorStakingSupport(for: wallet, chain: chain) { [weak self] result in
            if let reason = result.subtensorBlockedReason {
                onRefusal(reason)
            }

            self?.presentOperationCompletion(
                on: sheetPresentingView,
                by: result,
                successRouteClosure: successClosure
            )
        }
    }
}
