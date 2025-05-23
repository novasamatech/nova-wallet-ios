import Foundation
import Foundation_iOS
import NovaCrypto

struct MnemonicTextNormalizer: TextProcessing {
    func process(text: String) -> String {
        let whitespacesAndNewlines = CharacterSet.whitespacesAndNewlines

        return text
            .split(whereSeparator: { $0.unicodeScalars.allSatisfy(whitespacesAndNewlines.contains(_:)) })
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
