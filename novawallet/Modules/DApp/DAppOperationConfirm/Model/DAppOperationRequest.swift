import Foundation
import SubstrateSdk

struct DAppOperationRequest {
    let transportName: String
    let identifier: String
    let wallet: MetaAccountModel
    let chain: ChainModel
    let dApp: String
    let dAppIcon: URL?
    let operationData: JSON
}

struct DAppOperationResponse {
    let signature: Data?
}
