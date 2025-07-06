import Foundation

final class DelegatedSignValidationWireframe: DelegatedSignValidationWireframeProtocol {
    let completionClosure: DelegatedSignValidationCompletion

    init(completionClosure: @escaping DelegatedSignValidationCompletion) {
        self.completionClosure = completionClosure
    }

    func proceed(with sequence: DelegatedSignValidationSequence) {
        executeValidation(
            at: 0,
            from: sequence,
            state: DelegatedSignValidationSharedData()
        )
    }
}

private extension DelegatedSignValidationWireframe {
    func executeValidation(
        at index: Int,
        from sequence: DelegatedSignValidationSequence,
        state: DelegatedSignValidationSharedData
    ) {
        guard index < sequence.count else {
            completionClosure(true)
            return
        }

        let nextClosure: (Bool) -> Void = { [weak self] result in
            if result {
                self?.executeValidation(
                    at: index + 1,
                    from: sequence,
                    state: state
                )
            } else {
                completionClosure(false)
            }
        }

        switch sequence.nodes[index] {
        case let .fee(node):
            executeFeeValidation(
                for: node,
                state: state,
                validationCompletion: nextClosure
            )
        case let .multisigOperation(node):
            executeMultisigOperationValidation(
                for: node,
                state: state,
                validationCompletion: nextClosure
            )
        }
    }
}

private extension DelegatedSignValidationWireframe {
    func executeFeeValidation(
        for node: DelegatedSignValidationSequence.FeeNode,
        state: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        switch node.delegationType {
        case .proxy:
            executeProxyFeeValidation(node: node, validationCompletion: validationCompletion)
        case .multisig:
            executeMultisigSignatoryFeeValidation(
                node: node,
                state: state,
                validationCompletion: validationCompletion
            )
        }
    }

    func executeProxyFeeValidation(
        node _: DelegatedSignValidationSequence.FeeNode,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}

    func executeMultisigSignatoryFeeValidation(
        node _: DelegatedSignValidationSequence.FeeNode,
        state _: DelegatedSignValidationSharedData,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}
}

private extension DelegatedSignValidationWireframe {
    func executeMultisigOperationValidation(
        for _: DelegatedSignValidationSequence.MultisigOperationNode,
        state _: DelegatedSignValidationSharedData,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}
}
