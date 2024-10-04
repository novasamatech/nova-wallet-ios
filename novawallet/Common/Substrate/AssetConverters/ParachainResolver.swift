import Foundation
import Operation_iOS

protocol ParachainResolving {
    func resolveChainId(
        by parachainId: ParaId,
        relaychainId: ChainModel.Id
    ) -> CompoundOperationWrapper<ChainModel.Id?>
}

final class ParachainResolver: ParachainResolving {
    static let assetHubParaId: ParaId = 1000

    func resolveChainId(
        by parachainId: ParaId,
        relaychainId: ChainModel.Id
    ) -> CompoundOperationWrapper<ChainModel.Id?> {
        guard parachainId == Self.assetHubParaId else {
            return .createWithResult(nil)
        }

        switch relaychainId {
        case KnowChainId.polkadot:
            return .createWithResult(KnowChainId.statemint)
        case KnowChainId.kusama:
            return .createWithResult(KnowChainId.statemine)
        default:
            return .createWithResult(nil)
        }
    }
}
