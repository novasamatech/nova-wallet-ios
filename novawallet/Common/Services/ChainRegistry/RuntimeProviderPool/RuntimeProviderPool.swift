import Foundation

protocol RuntimeProviderPoolProtocol {
    func setupRuntimeProviderIfNeeded(for chain: ChainModel) -> RuntimeProviderProtocol
    func destroyRuntimeProviderIfExists(for chainId: ChainModel.Id)
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
}

final class RuntimeProviderPool {
    let runtimeProviderFactory: RuntimeProviderFactoryProtocol
    private(set) var runtimeProviders: [ChainModel.Id: RuntimeProviderProtocol] = [:]

    private var mutex = NSLock()

    init(runtimeProviderFactory: RuntimeProviderFactoryProtocol) {
        self.runtimeProviderFactory = runtimeProviderFactory
    }
}

extension RuntimeProviderPool: RuntimeProviderPoolProtocol {
    func setupRuntimeProviderIfNeeded(for chain: ChainModel) -> RuntimeProviderProtocol {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let runtimeProvider = runtimeProviders[chain.chainId] {
            runtimeProvider.replaceChainData(chain)

            return runtimeProvider
        } else {
            let runtimeProvider = runtimeProviderFactory.createRuntimeProvider(for: chain)

            runtimeProviders[chain.chainId] = runtimeProvider

            runtimeProvider.setup()

            return runtimeProvider
        }
    }

    func destroyRuntimeProviderIfExists(for chainId: ChainModel.Id) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let runtimeProvider = runtimeProviders[chainId]
        runtimeProvider?.cleanup()

        runtimeProviders[chainId] = nil
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviders[chainId]
    }
}
