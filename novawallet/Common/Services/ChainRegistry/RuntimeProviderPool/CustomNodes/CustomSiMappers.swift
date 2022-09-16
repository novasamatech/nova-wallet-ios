import Foundation
import SubstrateSdk

enum CustomSiMappers {
    static var all: SiTypeMapping {
        OneOfSiTypeMapper(innerMappers: [
            SiDataTypeMapper(),
            WeightCompatabilityTypeMapper()
        ])
    }
}
