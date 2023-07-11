extension MessageSheetPresentable {
    func presentOperationCompletion(
        on view: ControllerBackedProtocol?,
        by checkResult: OperationCheckCommonResult,
        successRouteClosure: () -> Void
    ) {
        guard let view = view else {
            return
        }
        switch checkResult {
        case .available:
            successRouteClosure()
        case .ledgerNotSupported:
            presentSignerNotSupportedView(
                from: view,
                type: .ledger,
                completion: {}
            )
        case .noSigning:
            presentNoSigningView(from: view, completion: {})
        }
    }
}
