import Foundation
import SubstrateSdk
import BigInt

protocol JSONPrettyPrinting {
    func prettyPrinted(from json: JSON) -> JSON
}

final class ExtrinsicJSONProcessor: JSONPrettyPrinting {
    func prettyPrinted(from json: JSON) -> JSON {
        process(json: json)
    }

    private func process(json: JSON) -> JSON {
        if let bigInt = try? json.map(to: BigInt.self) {
            return process(bigInt: bigInt)
        }

        switch json {
        case .unsignedIntValue:
            return json
        case .signedIntValue:
            return json
        case .stringValue:
            return json
        case let .arrayValue(array):
            return process(array: array)
        case let .dictionaryValue(dictionary):
            return process(dictionary: dictionary)
        case .boolValue:
            return json
        case .null:
            return json
        }
    }

    private func process(bigInt: BigInt) -> JSON {
        let stringValue = String(bigInt)
        return .stringValue(stringValue)
    }

    private func process(dictionary: [String: JSON]) -> JSON {
        let newDict = dictionary.mapValues { process(json: $0) }
        return JSON.dictionaryValue(newDict)
    }

    private func process(array: [JSON]) -> JSON {
        if let bytesMapper = try? JSON.arrayValue(array).map(to: [StringScaleMapper<UInt8>].self) {
            let bytes = bytesMapper.map(\.value)
            let hexValue = Data(bytes).toHex(includePrefix: true)
            return JSON.stringValue(hexValue)
        } else {
            let newArray = array.map { process(json: $0) }
            return JSON.arrayValue(newArray)
        }
    }
}
