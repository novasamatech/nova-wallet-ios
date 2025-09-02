import Foundation
import NovaCrypto

protocol ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol?
}
