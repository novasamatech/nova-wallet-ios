import Foundation
import Operation_iOS

protocol SubtensorStakingStrategiesDataSourceProtocol {
    func fetchStrategies() -> CompoundOperationWrapper<[SubtensorStakingStrategy]>
}

struct SubtensorStakingPreviewData {
    let strategies: [SubtensorStakingStrategy]
    let availableBalance: String
}

protocol SubtensorStakingPreviewDataSourceProtocol: SubtensorStakingStrategiesDataSourceProtocol {
    func fetchPreviewData() -> CompoundOperationWrapper<SubtensorStakingPreviewData>
}

final class SubtensorStakingStrategiesMockDataSource: SubtensorStakingPreviewDataSourceProtocol {
    func fetchStrategies() -> CompoundOperationWrapper<[SubtensorStakingStrategy]> {
        .createWithResult(Self.strategies)
    }

    func fetchPreviewData() -> CompoundOperationWrapper<SubtensorStakingPreviewData> {
        .createWithResult(
            .init(
                strategies: Self.strategies,
                availableBalance: "48.2 TAO ($16,484)"
            )
        )
    }
}

private extension SubtensorStakingStrategiesMockDataSource {
    static let strategies: [SubtensorStakingStrategy] = [
        .init(
            kind: .steady,
            annualReturn: 0.07,
            range: .fixed,
            chartValues: [39.1, 41.5, 44, 46.4, 48.9, 51.8]
        ),
        .init(
            kind: .balanced,
            annualReturn: 0.25,
            range: .percentage(lower: -0.08, upper: 0.08),
            chartValues: [
                38.6, 39.6, 40.9, 42.2, 43.8, 45.6, 46.4, 48, 48.6, 50.5, 51.2,
                52.3, 52.6, 54.2, 54.8, 55.4, 55.8, 57.2, 57.6, 57.7, 58.4, 59.3,
                60.8, 62.5, 63.8, 64.5, 65.8, 66.1, 66, 66.5, 68, 69, 69.8, 70.2,
                70.2, 71.7, 72.1, 72, 73.1, 74.9, 74.9, 75.8, 76.7, 77.9, 79.9, 80.1,
                80.5, 81.5, 81.8, 83.2, 84.5, 86.6, 86.8
            ]
        ),
        .init(
            kind: .higherUpside,
            annualReturn: 0.40,
            range: .percentage(lower: -0.30, upper: 0.30),
            chartValues: [
                34.6, 39, 34.7, 28.1, 21.5, 19.4, 17.3, 19.9, 18.5, 24.4, 27.9,
                21.4, 28.1, 21.6, 21.6, 27, 23.5, 29, 24.3, 19.5, 7.7, 3.1, -2.5,
                9.6, 12.5, 22.4, 22.7, 40.6, 44.8, 60.1, 54.8, 64.3, 56.9, 68.1,
                77.6, 89.9, 92.6, 102.6, 103.9, 122.3, 123.3, 113.9, 109.1, 104.7,
                99.5, 86.8, 90.5, 97.8, 92.2, 95.3, 90, 103.4, 112.1
            ]
        )
    ]
}
