import Foundation
import SubstrateSdk

extension RuntimeCall where T == JSON {
    func toCallJSON() -> JSON {
        JSON.dictionaryValue([
            "module": JSON.stringValue(moduleName),
            "function": JSON.stringValue(callName),
            "args": args
        ])
    }
}
