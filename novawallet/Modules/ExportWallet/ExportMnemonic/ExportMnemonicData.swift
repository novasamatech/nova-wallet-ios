import Foundation
import NovaCrypto

struct ExportMnemonicData {
    let metaAccount: MetaAccountModel
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let chain: ChainModel
}
