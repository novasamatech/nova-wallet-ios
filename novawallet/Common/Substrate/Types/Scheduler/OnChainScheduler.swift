import Foundation
import SubstrateSdk

enum OnChainScheduler {
    static var lookupTaskPath: StorageCodingPath {
        StorageCodingPath(moduleName: "Scheduler", itemName: "Lookup")
    }

    struct TaskAddress: Decodable {
        let when: BlockNumber

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            when = try container.decode(StringScaleMapper<BlockNumber>.self).value
        }
    }
}
