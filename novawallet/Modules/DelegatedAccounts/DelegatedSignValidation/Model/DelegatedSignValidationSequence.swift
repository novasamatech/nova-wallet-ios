import Foundation
import SubstrateSdk

struct DelegatedSignValidationSequence {
    struct FeeNode {
        let account: MetaChainAccountResponse
        let call: AnyRuntimeCall
        let delegationType: DelegationType
    }

    struct MultisigOperationNode {
        let signatory: MetaChainAccountResponse
        let call: RuntimeCall<MultisigPallet.AsMultiCall<AnyRuntimeCall>>
        let multisig: ChainAccountResponse
    }

    struct OperationConfirmNode {
        let account: MetaChainAccountResponse
        let call: AnyRuntimeCall
        let delegationType: DelegationType
    }

    enum Node {
        case fee(FeeNode)
        case multisigOperation(MultisigOperationNode)
        case confirmation(OperationConfirmNode)
    }

    let nodes: [Node]
}

final class DelegatedSignValidationSequenceBuilder {
    var nodes: [DelegatedSignValidationSequence.Node] = []

    @discardableResult
    func adding(node: DelegatedSignValidationSequence.Node) -> Self {
        nodes.append(node)

        return self
    }

    func build() -> DelegatedSignValidationSequence {
        DelegatedSignValidationSequence(nodes: nodes)
    }
}
