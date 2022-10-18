import Foundation

struct ReferendumVotersModel {
    let voters: [ReferendumVoterLocal]
    let identites: [AccountAddress: AccountIdentity]
}
