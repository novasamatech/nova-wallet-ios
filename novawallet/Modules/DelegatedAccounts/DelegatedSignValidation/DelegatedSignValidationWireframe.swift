import Foundation

final class DelegatedSignValidationWireframe: DelegatedSignValidationWireframeProtocol {
    let completionClosure: DelegatedSignValidationCompletion

    init(completionClosure: @escaping DelegatedSignValidationCompletion) {
        self.completionClosure = completionClosure
    }

    func proceed(from view: ControllerBackedProtocol, with sequence: DelegatedSignValidationSequence) {
        executeValidation(
            at: 0,
            sequence: sequence,
            view: view,
            state: DelegatedSignValidationSharedData()
        )
    }

    func completeWithError() {
        completionClosure(false)
    }
}

private extension DelegatedSignValidationWireframe {
    func executeValidation(
        at index: Int,
        sequence: DelegatedSignValidationSequence,
        view: ControllerBackedProtocol,
        state: DelegatedSignValidationSharedData
    ) {
        guard index < sequence.nodes.count else {
            completionClosure(true)
            return
        }

        let nextClosure: (Bool) -> Void = { [weak self] result in
            if result {
                self?.executeValidation(
                    at: index + 1,
                    sequence: sequence,
                    view: view,
                    state: state
                )
            } else {
                self?.completionClosure(false)
            }
        }

        switch sequence.nodes[index] {
        case let .fee(node):
            executeFeeValidation(
                node: node,
                view: view,
                state: state,
                validationCompletion: nextClosure
            )
        case let .multisigOperation(node):
            executeMultisigOperationValidation(
                node: node,
                view: view,
                state: state,
                validationCompletion: nextClosure
            )
        }
    }
}

private extension DelegatedSignValidationWireframe {
    func executeFeeValidation(
        node: DelegatedSignValidationSequence.FeeNode,
        view: ControllerBackedProtocol,
        state: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        switch node.delegationType {
        case .proxy:
            executeProxyFeeValidation(
                node: node,
                view: view,
                validationCompletion: validationCompletion
            )
        case .multisig:
            executeMultisigSignatoryFeeValidation(
                node: node,
                view: view,
                state: state,
                validationCompletion: validationCompletion
            )
        }
    }

    func executeProxyFeeValidation(
        node _: DelegatedSignValidationSequence.FeeNode,
        view _: ControllerBackedProtocol,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}

    func executeMultisigSignatoryFeeValidation(
        node _: DelegatedSignValidationSequence.FeeNode,
        view _: ControllerBackedProtocol,
        state _: DelegatedSignValidationSharedData,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}
}

private extension DelegatedSignValidationWireframe {
    func executeMultisigOperationValidation(
        node _: DelegatedSignValidationSequence.MultisigOperationNode,
        view _: ControllerBackedProtocol,
        state _: DelegatedSignValidationSharedData,
        validationCompletion _: @escaping DelegatedSignValidationCompletion
    ) {}
}
