import Foundation
import SubstrateSdk

struct CustomAssetMapper {
    enum MapperError: Error {
        case unexpectedType(_ type: String?)
        case invalidJson(_ type: String?)
    }

    let type: String?
    let typeExtras: JSON?

    private func mapAssetWithExtras<T>(
        nativeHandler: () -> T,
        statemineHandler: (StatemineAssetExtras) -> T,
        ormlHandler: (OrmlTokenExtras) -> T
    ) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            guard let wrappedExtras = try? typeExtras?.map(to: StatemineAssetExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return statemineHandler(wrappedExtras)
        case .orml:
            guard let wrappedExtras = try? typeExtras?.map(to: OrmlTokenExtras.self) else {
                throw MapperError.invalidJson(type)
            }

            return ormlHandler(wrappedExtras)
        case .none:
            return nativeHandler()
        }
    }

    private func mapAsset<T>(
        nativeHandler: () -> T,
        statemineHandler: () -> T,
        ormlHandler: () -> T
    ) throws -> T {
        let wrappedType: AssetType? = try type.map { value in
            if let typeValue = AssetType(rawValue: value) {
                return typeValue
            } else {
                throw MapperError.unexpectedType(type)
            }
        }

        switch wrappedType {
        case .statemine:
            return statemineHandler()
        case .orml:
            return ormlHandler()
        case .none:
            return nativeHandler()
        }
    }
}

extension CustomAssetMapper {
    func historyAssetId() throws -> String? {
        try mapAssetWithExtras(
            nativeHandler: { nil },
            statemineHandler: { $0.assetId },
            ormlHandler: { $0.currencyIdScale }
        )
    }
}
