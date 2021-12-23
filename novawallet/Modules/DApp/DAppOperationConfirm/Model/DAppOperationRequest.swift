import Foundation
import SubstrateSdk

struct DAppOperationRequest {
    let identifier: String
    let wallet: MetaAccountModel
    let chain: ChainModel
    let dApp: String
    let operationData: JSON
}

struct DAppOperationResponse {
    let signature: Data?
}
