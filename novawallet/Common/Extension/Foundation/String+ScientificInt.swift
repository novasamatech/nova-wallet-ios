import Foundation

extension String {
    func convertFromScientificUInt() -> String? {
        let baseExpComponents = components(separatedBy: CharacterSet(charactersIn: "eE"))

        guard
            baseExpComponents.count == 2,
            let exponent = Int(baseExpComponents[1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        guard exponent >= 0 else {
            return nil
        }

        let baseString = baseExpComponents[0].trimmingCharacters(in: .whitespaces)

        let decimalAndIntComponents = baseString.components(separatedBy: ".")

        guard
            decimalAndIntComponents.count <= 2,
            let intString = decimalAndIntComponents.first?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }

        let decimalString = decimalAndIntComponents.count == 2 ?
            decimalAndIntComponents[1].trimmingCharacters(in: .whitespaces) : ""

        if exponent > decimalString.count {
            let neededZeros = exponent - decimalString.count
            let zeroString = String(repeating: "0", count: neededZeros)

            return intString + decimalString + zeroString
        } else {
            let partCount = decimalString.count - exponent
            let partialDecimalString = decimalString.prefix(partCount)

            return baseString + String(partialDecimalString)
        }
    }
}
