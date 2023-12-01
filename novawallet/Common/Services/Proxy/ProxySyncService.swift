import SubstrateSdk
import RobinHood
import BigInt

class ProxySyncService: BaseSyncService {
    let repository: AnyDataProviderRepository<ChainModel>
    
    override func performSyncUp() {}

    override func stopSyncUp() {}
}

