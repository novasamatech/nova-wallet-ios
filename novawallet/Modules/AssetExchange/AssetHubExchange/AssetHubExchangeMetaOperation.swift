import Foundation

final class AssetHubExchangeMetaOperation: AssetExchangeBaseMetaOperation {}

extension AssetHubExchangeMetaOperation: AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel { .swap }
}