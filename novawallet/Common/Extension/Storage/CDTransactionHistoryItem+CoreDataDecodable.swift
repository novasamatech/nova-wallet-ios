import Foundation
import RobinHood
import CoreData

extension CDTransactionItem: CoreDataCodable {
    public func populate(from decoder: Decoder, using _: NSManagedObjectContext) throws {
        let container = try decoder.container(keyedBy: TransactionHistoryItem.CodingKeys.self)

        let sourceValue = try container.decode(TransactionHistoryItemSource.self, forKey: .source)
        source = sourceValue.rawValue
        chainId = try container.decode(String.self, forKey: .chainId)

        let assetId = try container.decode(UInt32.self, forKey: .assetId)
        self.assetId = Int32(bitPattern: assetId)

        let hash = try container.decode(String.self, forKey: .txHash)
        txHash = hash
        identifier = TransactionHistoryItem.createIdentifier(from: hash, source: sourceValue)

        sender = try container.decode(String.self, forKey: .sender)
        receiver = try container.decodeIfPresent(String.self, forKey: .receiver)
        amountInPlank = try container.decodeIfPresent(String.self, forKey: .amountInPlank)
        status = try container.decode(Int16.self, forKey: .status)

        timestamp = try container.decode(Int64.self, forKey: .timestamp)

        if let fee = try container.decodeIfPresent(String.self, forKey: .fee) {
            self.fee = fee
        }

        let callPath = try container.decode(CallCodingPath.self, forKey: .callPath)
        callName = callPath.callName
        moduleName = callPath.moduleName

        call = try container.decodeIfPresent(Data.self, forKey: .call)

        if let number = try container.decodeIfPresent(UInt64.self, forKey: .blockNumber) {
            blockNumber = NSNumber(value: number)
        } else {
            blockNumber = nil
        }

        if let index = try container.decodeIfPresent(Int16.self, forKey: .txIndex) {
            txIndex = NSNumber(value: index)
        } else {
            txIndex = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TransactionHistoryItem.CodingKeys.self)

        try container.encodeIfPresent(TransactionHistoryItemSource(rawValue: source), forKey: .source)
        try container.encodeIfPresent(chainId, forKey: .chainId)
        try container.encode(UInt32(bitPattern: assetId), forKey: .assetId)
        try container.encodeIfPresent(txHash, forKey: .txHash)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(receiver, forKey: .receiver)
        try container.encodeIfPresent(amountInPlank, forKey: .amountInPlank)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(fee, forKey: .fee)
        try container.encodeIfPresent(blockNumber?.uint64Value, forKey: .blockNumber)
        try container.encodeIfPresent(txIndex?.int16Value, forKey: .txIndex)

        if let moduleName = moduleName, let callName = callName {
            let callPath = CallCodingPath(moduleName: moduleName, callName: callName)
            try container.encode(callPath, forKey: .callPath)
        }

        try container.encodeIfPresent(call, forKey: .call)
    }
}
