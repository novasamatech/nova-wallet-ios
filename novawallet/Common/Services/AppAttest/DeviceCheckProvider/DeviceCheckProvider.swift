import DeviceCheck
import Operation_iOS

protocol DeviceCheckProviding {
    func fetchDeviceToken() -> CompoundOperationWrapper<DeviceCheckResult>
}

final class DeviceCheckProvider {
    let device: DCDevice = .current
    public init() {}
}

extension DeviceCheckProvider: DeviceCheckProviding {
    public func fetchDeviceToken() -> CompoundOperationWrapper<DeviceCheckResult> {
        let operation = AsyncClosureOperation<DeviceCheckResult> { [device] completion in
            guard device.isSupported else {
                completion(.success(DeviceCheckResult.unsupported))
                return
            }

            device.generateToken { data, error in
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }

                guard let data else {
                    completion(.failure(DeviceCheckError.invalidData))
                    return
                }

                completion(.success(DeviceCheckResult.supported(data)))
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
