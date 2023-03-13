enum ReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> ControllerBackedProtocol? {
        guard let option = state.settings.value else {
            return nil
        }

        if
            state.supportsDelegations(for: option),
            let api = option.chain.externalApis?.governanceDelegations()?.first {
            return DelegationReferendumVotersViewFactory.createView(
                state: state,
                referendum: referendum,
                type: type,
                delegationApi: api
            )
        } else {
            return ReferendumOnChainVotersViewFactory.createView(
                state: state,
                referendum: referendum,
                type: type
            )
        }
    }
}
