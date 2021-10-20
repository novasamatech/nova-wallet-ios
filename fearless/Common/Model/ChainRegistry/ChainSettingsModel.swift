import RobinHood

struct ChainSettingsModel: Equatable, Codable, Hashable {
    let autobalanced: Bool
    let chainId: ChainModel.Id
}

extension ChainSettingsModel: Identifiable {
    var identifier: String { chainId }
}
