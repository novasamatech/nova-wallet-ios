import Foundation

struct SubtensorSubnetLogoResolver {
    let config: SubtensorEarnConfig

    func url(for subnet: SubtensorSubnetRef) -> URL? {
        guard
            let baseUrl = config.logoBaseUrl,
            let logo = config.subnetEntry(for: subnet)?.logo,
            Self.isPlainFileName(logo) else {
            return nil
        }

        return baseUrl.appendingPathComponent(logo, isDirectory: false)
    }
}

private extension SubtensorSubnetLogoResolver {
    static let fileNameAlphabet = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
    )

    static func isPlainFileName(_ value: String) -> Bool {
        guard !value.isEmpty, value != ".", value != ".." else {
            return false
        }

        return value.unicodeScalars.allSatisfy(fileNameAlphabet.contains)
    }
}
