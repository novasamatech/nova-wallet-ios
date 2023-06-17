import Foundation

protocol JsonCanonicalizerProtocol {
    func canonicalizeJSON(_ data: Data) throws -> String?
}

final class JsonCanonicalizer: JsonCanonicalizerProtocol {
    func canonicalizeJSON(_ data: Data) throws -> String? {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        let canonicalizedObject = canonicalize(jsonObject)
        return canonicalizedObject
    }

    private func canonicalize(_ object: Any) -> String {
        var result = ""

        if let string = object as? String {
            result += "\"\(canonicalize(string: string))\""
        } else if let array = object as? [Any] {
            result += canonicalize(array: array)
        } else if let dictionary = object as? [String: Any] {
            result += canonicalize(dictionary: dictionary)
        } else if object is NSNull {
            result += "null"
        }

        return result
    }

    private func canonicalize(array: [Any]) -> String {
        "[" + array.map(canonicalize).joined(separator: ",") + "]"
    }

    private func canonicalize(dictionary: [String: Any]) -> String {
        "{" +
            Array(dictionary.keys)
            .sortedLexicographically()
            .map { key in
                "\"\(canonicalize(string: key))\":" + canonicalize(dictionary[key])
            }
            .joined(separator: ",") +
            "}"
    }

    private func canonicalize(string: String) -> String {
        string.reduce(into: "") { result, char in
            switch char {
            case "\n":
                result += escape("n")
            case "\u{0008}": // Backspace
                result += escape("b")
            case "\u{000C}": // Form feed
                result += escape("f")
            case "\r":
                result += escape("r")
            case "\t":
                result += escape("t")
            case "\"", "\\":
                result += escape(char)
            default:
                if var asciiValue = char.unicodeScalars.first?.value,
                   char.isASCII, asciiValue < 0x20 {
                    result += escape("u")
                    result += (0 ..< 4).reduce(into: "") { result, _ in
                        let hex = asciiValue >> 12
                        if let unicodeScalar = UnicodeScalar(hex > 9 ? hex + 87 : hex + 48) {
                            result.append(Character(unicodeScalar))
                        }
                        asciiValue <<= 4
                    }
                } else {
                    result.append(char)
                }
            }
        }
    }

    private func escape(_ char: Character) -> String {
        "\\\(char)"
    }
}
