import Foundation
import SubstrateSdk

enum BIP32PathJunction {
    case hardened(value: UInt32)
    case soft(value: UInt32)
}

enum BIP32PathConstants {
    static let hardSeparator = "//"
    static let softSeparator = "/"
    static let hardFlag = UInt32(0x8000_0000)
}

final class LedgerPathBuilder {
    private var pathData = Data()

    func appending(junction: BIP32PathJunction) -> LedgerPathBuilder {
        let numericJunction: UInt32

        switch junction {
        case let .hardened(value):
            numericJunction = BIP32PathConstants.hardFlag + value
        case let .soft(value):
            numericJunction = value
        }

        pathData.append(contentsOf: numericJunction.littleEndianBytes)

        return self
    }

    func appendingStandardJunctions(coin: UInt32, accountIndex: UInt32) -> LedgerPathBuilder {
        appending(junction: .hardened(value: 44))
            .appending(junction: .hardened(value: coin))
            .appending(junction: .hardened(value: accountIndex))
            .appending(junction: .hardened(value: 0))
            .appending(junction: .hardened(value: 0))
    }

    func build() -> Data {
        pathData
    }
}

protocol LedgerPathConverting {
    func convertToChaincodesData(from path: String) throws -> Data
    func convertFromChaincodesData(from chaincodes: Data) throws -> String
}

enum LedgerPathConvertingError: Error {
    case invalidData(Data)
}

final class LedgerPathConverter: LedgerPathConverting {
    private func convertFromDataToIntegers(from data: Data, isLittleEndian: Bool) throws -> [UInt32] {
        guard data.count % 4 == 0 else {
            throw LedgerPathConvertingError.invalidData(data)
        }

        var result: [UInt32] = []

        for offset in stride(from: 0, to: data.count, by: 4) {
            let chunk = data.subdata(in: offset ..< min(offset + 4, data.count))

            let value = if isLittleEndian {
                UInt32(littleEndianData: chunk)
            } else {
                UInt32(bigEndianData: chunk)
            }

            result.append(value)
        }

        return result
    }

    func convertToChaincodesData(from path: String) throws -> Data {
        let chainCodes = try BIP32JunctionFactory().parse(path: path)

        return chainCodes.chaincodes.reduce(into: Data()) { totalData, chainCode in
            // convert chaincodes to little endian before appending
            totalData.append(Data(chainCode.data.reversed()))
        }
    }

    func convertFromChaincodesData(from chaincodes: Data) throws -> String {
        let junctions = try convertFromDataToIntegers(from: chaincodes, isLittleEndian: true)

        return junctions.reduce(String()) { result, junction in
            if (junction & BIP32PathConstants.hardFlag) > 0 {
                let value = junction ^ BIP32PathConstants.hardFlag
                return result + BIP32PathConstants.hardSeparator + String(value)
            } else {
                return result + BIP32PathConstants.softSeparator + String(junction)
            }
        }
    }
}
