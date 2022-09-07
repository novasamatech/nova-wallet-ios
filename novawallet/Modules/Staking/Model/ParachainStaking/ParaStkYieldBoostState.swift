import Foundation

enum ParaStkYieldBoostState {
    struct Task {
        let taskId: AutomationTime.TaskId
        let collatorId: AccountId
    }

    case unsupported
    case supported(tasks: [Task])

    init(automationTimeTasks: [AutomationTime.TaskId: AutomationTime.Task]) {
        let tasks: [Task] = automationTimeTasks.compactMap { keyValue in
            switch keyValue.value.action {
            case let .autoCompoundDelegatedStake(params):
                return Task(taskId: keyValue.key, collatorId: params.collator)
            default:
                return nil
            }
        }

        self = .supported(tasks: tasks)
    }
}
