import Foundation
import SubstrateSdk

extension AutomationTime {
    struct CancelTaskCall: Codable {
        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
        }

        @BytesCodable var taskId: AutomationTime.TaskId

        var runtimeCall: RuntimeCall<CancelTaskCall> {
            RuntimeCall(moduleName: "AutomationTime", callName: "cancel_task", args: self)
        }
    }
}
