import CryptoKit
import Foundation

extension Data {
    /// Lowercase hex SHA-256 of the data, for stable content de-duplication.
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

extension String {
    /// Lowercase hex SHA-256 of the UTF-8 bytes.
    var sha256Hex: String {
        Data(utf8).sha256Hex
    }
}
