import Foundation

struct LightChainModel: Decodable, ChainViewModelSource {
    let chainId: ChainModel.Id
    let name: String
    let icon: URL?
    let options: [LocalChainOptions]?
}
