import Foundation
import SubstrateSdk

struct DelegatedSignValidationSequence {
    struct FeeNode {
        let account: MetaAccountChainResponse
        let call: AnyRuntimeCall
        let delegationType: DelegationType
    }

    struct MultisigOperationNode {
        let signatory: MetaAccountChainResponse
        let call: RuntimeCall<MultisigPallet.AsMultiCall<AnyRuntimeCall>>
    }

    enum Node {
        case fee(FeeNode)
        case multisigOperation(MultisigOperationNode)
    }

    let nodes: [Node]
}
