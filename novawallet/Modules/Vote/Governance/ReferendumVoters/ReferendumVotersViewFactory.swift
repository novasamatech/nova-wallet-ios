enum ReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> ControllerBackedProtocol? {
        guard let chain = state.settings.value?.chain else {
            return nil
        }

        if chain.externalApis?.governanceDelegations()?.first != nil {
            return DelegationReferendumVotersViewFactory.createView(
                state: state,
                referendum: referendum,
                type: type
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
