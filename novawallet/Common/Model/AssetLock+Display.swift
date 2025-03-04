import Foundation

extension AssetLock {
    var displayModuleAndIdTitle: String? {
        guard let displayId else {
            return module?.capitalized
        }

        guard let module, AssetLockStorage(rawValue: storage) == .freezes else {
            return displayId.capitalized
        }

        return "\(module.capitalized): \(displayId.capitalized)"
    }
}
