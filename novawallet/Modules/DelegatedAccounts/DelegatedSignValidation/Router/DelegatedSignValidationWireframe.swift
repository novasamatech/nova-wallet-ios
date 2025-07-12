import Foundation

final class DelegatedSignValidationWireframe: DelegatedSignValidationWireframeProtocol {
    let completionClosure: DelegatedSignValidationCompletion

    private var flowHolder: AnyObject?

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
            self?.flowHolder = nil

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
        case let .confirmation(node):
            executeOperationConfirmation(
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
                state: state,
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
        node: DelegatedSignValidationSequence.FeeNode,
        view: ControllerBackedProtocol,
        state: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        guard let presenter = ProxySignValidationViewFactory.createPresenter(
            from: view,
            callSender: node.account,
            call: node.call,
            validationSharedData: state,
            completionClosure: validationCompletion
        ) else {
            completionClosure(false)
            return
        }

        flowHolder = presenter

        presenter.setup()
    }

    func executeMultisigSignatoryFeeValidation(
        node: DelegatedSignValidationSequence.FeeNode,
        view: ControllerBackedProtocol,
        state: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        guard let presenter = MultisigFeeValidationViewFactory.createPresenter(
            from: view,
            callSender: node.account,
            call: node.call,
            validationSharedData: state,
            completionClosure: validationCompletion
        ) else {
            completionClosure(false)
            return
        }

        flowHolder = presenter

        presenter.setup()
    }
}

private extension DelegatedSignValidationWireframe {
    func executeMultisigOperationValidation(
        node: DelegatedSignValidationSequence.MultisigOperationNode,
        view: ControllerBackedProtocol,
        state: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        guard let presenter = MultisigOpValidationViewFactory.createPresenter(
            from: view,
            validationNode: node,
            validationState: state,
            completionClosure: validationCompletion
        ) else {
            completionClosure(false)
            return
        }

        flowHolder = presenter

        presenter.setup()
    }
}

private extension DelegatedSignValidationWireframe {
    func executeOperationConfirmation(
        node: DelegatedSignValidationSequence.OperationConfirmNode,
        view: ControllerBackedProtocol,
        state _: DelegatedSignValidationSharedData,
        validationCompletion: @escaping DelegatedSignValidationCompletion
    ) {
        let confirmationPresenter = DelegatedSignConfirmationViewFactory.createPresenter(
            from: node.account.metaId,
            delegationType: node.delegationType,
            delegateAccountResponse: node.account.chainAccount,
            completionClosure: validationCompletion,
            viewController: view.controller
        )

        flowHolder = confirmationPresenter

        confirmationPresenter.setup()
    }
}
