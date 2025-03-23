import Foundation

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
