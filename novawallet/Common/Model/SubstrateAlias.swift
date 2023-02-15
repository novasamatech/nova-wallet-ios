import Foundation

typealias AccountAddress = String
typealias AccountId = Data
typealias ParaId = UInt32
typealias FundIndex = UInt32
typealias BidderKey = UInt32
typealias BlockNumber = UInt32
typealias BlockTime = UInt64
typealias LeasingPeriod = UInt32
typealias LeasingOffset = UInt32
typealias Slot = UInt64
typealias SessionIndex = UInt32
typealias Moment = UInt32
typealias EraIndex = UInt32
typealias EraRange = (start: EraIndex, end: EraIndex)

extension AccountId {
    static func matchHex(_ value: String, chainFormat: ChainFormat) -> AccountId? {
        guard let data = try? Data(hexString: value) else {
            return nil
        }

        switch chainFormat {
        case .ethereum:
            return data.count == SubstrateConstants.ethereumAddressLength ? data : nil
        case .substrate:
            return data.count == SubstrateConstants.accountIdLength ? data : nil
        }
    }
}

extension BlockNumber {
    func secondsTo(block: BlockNumber, blockDuration: BlockTime) -> TimeInterval {
        let durationInSeconds = TimeInterval(blockDuration).seconds
        let diffBlock = TimeInterval(Int(block) - Int(self))
        let seconds = diffBlock * durationInSeconds
        return seconds
    }

    func toHex() -> String {
        var blockNumber = self

        return Data(
            Data(bytes: &blockNumber, count: MemoryLayout<UInt32>.size).reversed()
        ).toHex(includePrefix: true)
    }

    func blockBackInDays(_ days: Int, blockTime: BlockTime?) -> BlockNumber? {
        guard let blockTime = blockTime else {
            return nil
        }

        guard blockTime > 0 else {
            return self
        }

        let blocksInPast = BlockNumber(TimeInterval(days).secondsFromDays / TimeInterval(blockTime).seconds)

        guard self > blocksInPast else {
            return 0
        }

        return self - blocksInPast
    }
}

extension Moment {
    func seconds(from blockDuration: BlockTime) -> TimeInterval {
        let durationInSeconds = TimeInterval(blockDuration).seconds
        return TimeInterval(self) * durationInSeconds
    }
}

extension AccountAddress {
    var truncated: String {
        guard count > 9 else {
            return self
        }

        let prefix = self.prefix(4)
        let suffix = self.suffix(5)

        return "\(prefix)...\(suffix)"
    }
}
