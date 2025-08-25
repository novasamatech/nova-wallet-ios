import Foundation

extension String {
    var displayCall: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    var displayModule: String {
        replacingSnakeCase().replacingCamelCase().capitalized
    }

    var displayContractFunction: String {
        cuttingOffArguments().replacingSnakeCase().replacingCamelCase().capitalized
    }

    var hasAmbiguousFunctionName: Bool {
        lowercased().contains("transfer")
    }

    func cuttingOffArguments() -> String {
        // maps transfer(address _to, uint256 _value) to transfer
        let result = prefix(while: { $0 != "(" })

        return String(result)
    }

    func replacingSnakeCase() -> String {
        replacingOccurrences(of: "_", with: " ")
    }

    func replacingCamelCase() -> String {
        guard let first else { return self }

        var replacedCamelCase: String = "\(first.lowercased())"
        let upperCase = CharacterSet.uppercaseLetters
        for scalar in unicodeScalars.dropFirst() {
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
