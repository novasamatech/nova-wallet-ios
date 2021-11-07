import Foundation
import IrohaCrypto

struct ExportMnemonicData {
    let metaAccount: MetaAccountModel
    let mnemonic: IRMnemonicProtocol
    let derivationPath: String?
    let chain: ChainModel
}
