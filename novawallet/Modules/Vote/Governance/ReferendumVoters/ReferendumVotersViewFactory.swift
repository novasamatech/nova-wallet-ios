enum ReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> ControllerBackedProtocol? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        if let governanceDelegationsApi = chain.externalApis?.governanceDelegations()?.first {
            return DelegationReferendumVotersViewFactory.createView(
                state: state,
                referendum: referendum,
                type: type,
                delegationApi: governanceDelegationsApi
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
