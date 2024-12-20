import Foundation

final class CrosschainExchangeMetaOperation: AssetExchangeBaseMetaOperation {}

extension CrosschainExchangeMetaOperation: AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel { .transfer }
}
