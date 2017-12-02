import Foundation

extension UInt64: Parameterizable {
    public static var uniqueSlug: String {
        return "id"
    }

    public static func make(for parameter: String) throws -> UInt64 {
        guard let int = UInt64(parameter) else {
            throw RouterError.invalidParameter
        }

        return int
    }
}
