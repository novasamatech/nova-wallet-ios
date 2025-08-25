import Foundation
import SubstrateSdk

extension AssetModel {
    func getOrmlCurrencyId<T: Decodable>(for codingFactory: RuntimeCoderFactoryProtocol) throws -> T? {
        switch AssetType(rawType: type) {
        case .orml, .ormlHydrationEvm:
            guard let extras = try typeExtras?.map(to: OrmlTokenExtras.self) else {
                return nil
            }

            let rawCurrencyId = try Data(hexString: extras.currencyIdScale)

            let decoder = try codingFactory.createDecoder(from: rawCurrencyId)
            let value: T = try decoder.read(of: extras.currencyIdType)

            return value
        case .none, .equilibrium, .evmNative, .evmAsset, .statemine:
            return nil
        }
    }
}
