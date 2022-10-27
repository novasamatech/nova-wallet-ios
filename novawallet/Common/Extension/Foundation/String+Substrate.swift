import Foundation

extension String {
    var displayCall: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    var displayModule: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    func replacingSnakeCase() -> String {
        replacingOccurrences(of: "_", with: " ")
    }

    func replacingCamelCase() -> String {
        var replacedCamelCase: String = ""
        let upperCase = CharacterSet.uppercaseLetters
        for scalar in unicodeScalars {
            if upperCase.contains(scalar) {
                replacedCamelCase.append(" ")
            }

            let character = Character(scalar)
            replacedCamelCase.append(character)
        }

        return replacedCamelCase
    }

    func twoLineString(with threshold: Int) -> String {
        guard count > threshold else {
            return self
        }

        let leftPartCount = count / 2

        guard leftPartCount > 0 else {
            return self
        }

        return prefix(leftPartCount) + "\n" + suffix(count - leftPartCount)
    }

    var twoLineAddress: String {
        let leftPartCount = count / 2

        guard leftPartCount > 0 else {
            return self
        }

        return prefix(leftPartCount) + "\n" + suffix(count - leftPartCount)
    }
}
