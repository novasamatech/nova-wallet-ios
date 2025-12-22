import Foundation
import Operation_iOS

protocol CrowdloanLocalStorageHandler: AnyObject {
    func handleCrowdloans(
        result: Result<[DataProviderChange<CrowdloanContribution>], Error>,
        accountId: AccountId,
        chainAssetId: ChainAssetId
    )
}

extension CrowdloanLocalStorageHandler {
    func handleCrowdloans(
        result _: Result<[DataProviderChange<CrowdloanContribution>], Error>,
        accountId _: AccountId,
        chainAssetId _: ChainAssetId
    ) {}
}
