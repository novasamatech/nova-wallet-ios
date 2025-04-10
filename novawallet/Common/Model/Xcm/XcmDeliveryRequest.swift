import Foundation

struct XcmDeliveryRequest {
    let message: XcmUni.VersionedMessage
    let fromChainId: ChainModel.Id
    let toParachainId: ParaId?
}
