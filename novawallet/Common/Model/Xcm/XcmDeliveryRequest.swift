import Foundation

struct XcmDeliveryRequest {
    let message: Xcm.Message
    let fromChainId: ChainModel.Id
    let toParachainId: ParaId?
}
