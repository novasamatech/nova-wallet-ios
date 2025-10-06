import Foundation

extension ChainRegistryProtocol {
    func getTimelineChainOrError(for chainId: ChainModel.Id) throws -> ChainModel {
        let originalChain = try getChainOrError(for: chainId)

        guard let timelineChainId = originalChain.timelineChain else {
            return originalChain
        }

        return try getChainOrError(for: timelineChainId)
    }
}
