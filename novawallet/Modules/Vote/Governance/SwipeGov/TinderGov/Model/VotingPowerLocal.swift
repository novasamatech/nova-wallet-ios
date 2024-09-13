import Foundation
import Operation_iOS
import BigInt

struct VotingPowerLocal {
    let chainId: ChainModel.Id
    let metaId: MetaAccountModel.Id
    let conviction: ConvictionLocal
    let amount: BigUInt

    var votingAmount: BigUInt {
        conviction.votes(for: amount)
    }
}

extension VotingPowerLocal: Identifiable {
    static func identifier(
        metaId: String,
        chainId: ChainModel.Id
    ) -> String {
        [
            metaId,
            chainId
        ].joined(with: .dash)
    }

    var identifier: String {
        Self.identifier(
            metaId: metaId,
            chainId: chainId
        )
    }
}
