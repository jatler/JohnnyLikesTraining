import Foundation

enum DistanceFormatter {
    private static let kmToMi = 0.621371

    static func miles(from km: Double) -> Double {
        km * kmToMi
    }

    static func formatted(km: Double, decimals: Int = 1) -> String {
        let mi = miles(from: km)
        return String(format: "%.\(decimals)f mi", mi)
    }
}
