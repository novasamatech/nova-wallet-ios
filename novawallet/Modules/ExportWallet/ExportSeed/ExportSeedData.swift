import Foundation

struct ExportSeedData {
    let metaAccount: MetaAccountModel
    let seed: Data
    let derivationPath: String?
    let chain: ChainModel
}
