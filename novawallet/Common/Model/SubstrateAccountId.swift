import Foundation
import NovaCrypto

final class AccountIdWrapper: IRPublicKeyProtocol {
    let data: Data

    init(rawData data: Data) throws {
        self.data = data
    }

    func rawData() -> Data { data }
}
