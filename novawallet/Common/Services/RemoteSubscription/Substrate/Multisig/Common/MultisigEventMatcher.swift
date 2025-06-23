import SubstrateSdk

struct MultisigEventMatcher {
    private let codingFactory: RuntimeCoderFactoryProtocol

    init(codingFactory: RuntimeCoderFactoryProtocol) {
        self.codingFactory = codingFactory
    }

    func matchMultisig(event: Event) -> MultisigEvent? {
        let pathsToMatch: Set<EventCodingPath> = [
            MultisigPallet.newMultisigEventPath,
            MultisigPallet.multisigApprovalEventPath
        ]

        guard codingFactory.metadata.eventMatches(
            event,
            oneOf: pathsToMatch
        ) else { return nil }

        let context = codingFactory.createRuntimeJsonContext().toRawContext()

        return MultisigEvent(
            params: event.params,
            context: context
        )
    }
}
