import Foundation
import SubstrateSdk

protocol ParitySignerScanMatcherProtocol {
    func match(code: QRCodeData) -> ParitySignerWalletScan?
}

final class ParitySignerScanMatcher {
    private enum Constants {
        static let type: String = "substrate"
        static let separator: String = ":"
    }

    private func match(code: String) -> ParitySignerWalletScan? {
        let components = code.components(separatedBy: Constants.separator)

        guard components.count >= 3 else {
            return nil
        }

        guard components[0] == Constants.type else {
            return nil
        }

        guard let genesisHash = try? Data(hexString: components[2]) else {
            return nil
        }

        let singleAddress = ParitySignerWalletScan.SingleAddress(
            address: components[1],
            genesisHash: genesisHash
        )

        return .singleAddress(singleAddress)
    }

    private func match(rawData: Data) -> ParitySignerWalletScan? {
        do {
            let decoder = try ScaleDecoder(data: rawData)

            let rootKeysInfo = try ParitySignerWalletScan.RootKeysInfo(scaleDecoder: decoder)

            return .rootKeys(rootKeysInfo)
        } catch {
            return nil
        }
    }
}

extension ParitySignerScanMatcher: ParitySignerScanMatcherProtocol {
    func match(code: QRCodeData) -> ParitySignerWalletScan? {
        switch code {
        case let .plain(plainText):
            match(code: plainText)
        case let .raw(rawData):
            match(rawData: rawData)
        }
    }
}
