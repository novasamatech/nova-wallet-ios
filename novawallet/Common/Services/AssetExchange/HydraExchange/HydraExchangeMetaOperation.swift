import Foundation

class HydraExchangeMetaOperation: AssetExchangeBaseMetaOperation {}

extension HydraExchangeMetaOperation: AssetExchangeMetaOperationProtocol {
    var label: AssetExchangeMetaOperationLabel { .swap }
    var requiresOriginAccountKeepAlive: Bool { false }
}
