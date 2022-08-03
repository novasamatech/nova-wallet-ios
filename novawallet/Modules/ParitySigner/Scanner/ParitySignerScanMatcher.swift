import Foundation

protocol ParitySignerScanMatcherProtocol {
    func match(code: String) -> ParitySignerAddressScan?
}

final class ParitySignerScanMatcher: ParitySignerScanMatcherProtocol {
    private enum Constants {
        static let type: String = "substrate"
        static let separator: String = ":"
    }

    func match(code: String) -> ParitySignerAddressScan? {
        let components = code.components(separatedBy: Constants.separator)

        guard components.count >= 3 else {
            return nil
        }

        guard components[0] == Constants.type else {
            return nil
        }

        return ParitySignerAddressScan(address: components[1], chainId: components[2])
    }
}
