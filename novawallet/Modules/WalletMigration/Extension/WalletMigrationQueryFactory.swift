import Foundation
import Foundation_iOS
import NovaCrypto

final class WalletMigrationQueryFactory {}

extension WalletMigrationQueryFactory: WalletMigrationQueryFactoryProtocol {
    func stringify(data: Data) -> String { data.toHex() }

    func dataFrom(string: String) throws -> Data {
        try Data(hexString: string)
    }
}
