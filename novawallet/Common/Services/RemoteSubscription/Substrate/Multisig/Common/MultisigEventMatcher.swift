import SubstrateSdk

struct MultisigEventMatcher {
    private let codingFactory: RuntimeCoderFactoryProtocol

    init(codingFactory: RuntimeCoderFactoryProtocol) {
        self.codingFactory = codingFactory
    }

    func matchMultisig(eventRecord: EventRecord) -> MultisigEvent? {
        let pathsToMatch: Set<EventCodingPath> = [
            MultisigPallet.newMultisigEventPath,
            MultisigPallet.multisigApprovalEventPath
        ]

        guard codingFactory.metadata.eventMatches(
            eventRecord.event,
            oneOf: pathsToMatch
        ) else { return nil }

        guard let extrinsicIndex = eventRecord.extrinsicIndex else { return nil }

        let context = codingFactory.createRuntimeJsonContext().toRawContext()

        return MultisigEvent(
            params: eventRecord.event.params,
            extrinsicIndex: extrinsicIndex,
            context: context
        )
    }
}
