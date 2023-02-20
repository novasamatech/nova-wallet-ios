import Foundation

struct DelegateVotedReferendaModel {
    let offchainVotes: GovernanceOffchainVotes
    let referendums: [ReferendumIdLocal: ReferendumLocal]
}
