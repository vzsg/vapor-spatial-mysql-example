import Random

extension RandomProtocol {
    func makeDouble(min: Double, max: Double) -> Double {
        let base = Double((try? makeUInt()) ?? 0) / Double(UInt.max)
        let range = max - min
        return base * range + min
    }
}
