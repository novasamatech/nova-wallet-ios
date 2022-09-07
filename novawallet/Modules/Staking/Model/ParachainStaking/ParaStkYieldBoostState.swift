import Foundation

enum ParaStkYieldBoostState {
    struct Task: Codable, Equatable {
        let taskId: AutomationTime.TaskId
        let collatorId: AccountId

        static func listFromAutomationTime(tasks: [AutomationTime.TaskId: AutomationTime.Task]) -> [Task] {
            tasks.compactMap { keyValue in
                switch keyValue.value.action {
                case let .autoCompoundDelegatedStake(params):
                    return Task(taskId: keyValue.key, collatorId: params.collator)
                default:
                    return nil
                }
            }
        }
    }

    case unsupported
    case supported(tasks: [Task])

    init(automationTimeTasks: [AutomationTime.TaskId: AutomationTime.Task]) {
        let tasks: [Task] = Task.listFromAutomationTime(tasks: automationTimeTasks)

        self = .supported(tasks: tasks)
    }
}
