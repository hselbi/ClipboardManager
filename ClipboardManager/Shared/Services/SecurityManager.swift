import Foundation
import CryptoKit
import Security
import LocalAuthentication

// MARK: - Security Manager

/// Handles encryption, secure storage, and biometric authentication
final class SecurityManager {
    // MARK: - Properties

    private let keychainService = "com.clipboard.manager"
    private let encryptionKeyTag = "com.clipboard.manager.encryption.key"

    static let shared = SecurityManager()

    private init() {}

    // MARK: - Encryption Key Management

    /// Get or create the encryption key
    func getEncryptionKey() throws -> SymmetricKey {
        // Try to load existing key from keychain
        if let keyData = try? loadFromKeychain(account: encryptionKeyTag) {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        // Store in keychain
        try saveToKeychain(data: keyData, account: encryptionKeyTag)

        return key
    }

    /// Delete the encryption key (use with caution - will make encrypted data unrecoverable)
    func deleteEncryptionKey() throws {
        try deleteFromKeychain(account: encryptionKeyTag)
    }

    // MARK: - Data Encryption

    /// Encrypt data using AES-GCM
    func encrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }

        return combined
    }

    /// Decrypt data using AES-GCM
    func decrypt(_ data: Data) throws -> Data {
        let key = try getEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    /// Encrypt string
    func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw SecurityError.invalidData
        }
        return try encrypt(data)
    }

    /// Decrypt to string
    func decryptToString(_ data: Data) throws -> String {
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw SecurityError.decryptionFailed
        }
        return string
    }

    // MARK: - Keychain Operations

    /// Save data to keychain
    func saveToKeychain(data: Data, account: String) throws {
        // Delete existing item first
        try? deleteFromKeychain(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }

    /// Load data from keychain
    func loadFromKeychain(account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw SecurityError.keychainError(status)
        }

        return data
    }

    /// Delete from keychain
    func deleteFromKeychain(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityError.keychainError(status)
        }
    }

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available
    func isBiometricAuthAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Get biometric type
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        default:
            return .none
        }
    }

    /// Authenticate with biometrics
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            throw SecurityError.biometricError(error)
        }
    }

    // MARK: - Sensitive Content Detection

    /// Check if text contains potential sensitive information
    func containsSensitiveContent(_ text: String) -> SensitiveContentResult {
        var detectedTypes: [SensitiveContentType] = []
        var confidence: Double = 0

        // Credit card patterns
        let creditCardPattern = "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b"
        if matchesPattern(text, pattern: creditCardPattern) {
            if luhnCheck(text.filter { $0.isNumber }) {
                detectedTypes.append(.creditCard)
                confidence = max(confidence, 0.95)
            }
        }

        // SSN pattern
        let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        if matchesPattern(text, pattern: ssnPattern) {
            detectedTypes.append(.ssn)
            confidence = max(confidence, 0.9)
        }

        // Email pattern (for detecting credentials)
        let emailPattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        if matchesPattern(text, pattern: emailPattern) {
            // Only flag if combined with password-like content
            let passwordIndicators = ["password", "pwd", "pass", "secret", "credential"]
            if passwordIndicators.contains(where: { text.lowercased().contains($0) }) {
                detectedTypes.append(.credentials)
                confidence = max(confidence, 0.85)
            }
        }

        // API key patterns
        let apiKeyPatterns = [
            "api[_-]?key\\s*[:=]\\s*['\"]?[A-Za-z0-9_-]{20,}",
            "secret[_-]?key\\s*[:=]\\s*['\"]?[A-Za-z0-9_-]{20,}",
            "access[_-]?token\\s*[:=]\\s*['\"]?[A-Za-z0-9_-]{20,}",
            "bearer\\s+[A-Za-z0-9_-]{20,}"
        ]

        for pattern in apiKeyPatterns {
            if matchesPattern(text, pattern: pattern) {
                detectedTypes.append(.apiKey)
                confidence = max(confidence, 0.8)
                break
            }
        }

        // Private key detection
        if text.contains("-----BEGIN") && text.contains("PRIVATE KEY-----") {
            detectedTypes.append(.privateKey)
            confidence = max(confidence, 0.99)
        }

        // Phone number (less sensitive, lower confidence)
        let phonePattern = "\\b(?:\\+?1[-.\\s]?)?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}\\b"
        if matchesPattern(text, pattern: phonePattern) {
            detectedTypes.append(.phoneNumber)
            confidence = max(confidence, 0.5)
        }

        return SensitiveContentResult(
            isSensitive: !detectedTypes.isEmpty,
            types: detectedTypes,
            confidence: confidence
        )
    }

    // MARK: - Helper Methods

    private func matchesPattern(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// Luhn algorithm check for credit card validation
    private func luhnCheck(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 && digits.count <= 19 else { return false }

        var sum = 0
        let reversedDigits = digits.reversed().enumerated()

        for (index, digit) in reversedDigits {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }

    // MARK: - Secure Clipboard Write

    /// Write to clipboard with auto-clear
    func writeSecureToClipboard(_ text: String, clearAfter seconds: TimeInterval) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Schedule clear
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Only clear if content hasn't changed
            if pasteboard.string(forType: .string) == text {
                pasteboard.clearContents()
            }
        }
        #else
        let pasteboard = UIPasteboard.general
        pasteboard.string = text

        // Schedule clear
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if pasteboard.string == text {
                pasteboard.string = ""
            }
        }
        #endif
    }

    // MARK: - Hash Generation

    /// Generate SHA256 hash of data
    func sha256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Generate SHA256 hash of string
    func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha256(data)
    }
}

// MARK: - Security Error

enum SecurityError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case keychainError(OSStatus)
    case biometricError(Error)
    case keyNotFound

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid data format"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .biometricError(let error):
            return "Biometric authentication failed: \(error.localizedDescription)"
        case .keyNotFound:
            return "Encryption key not found"
        }
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID

    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "lock"
        case .touchID: return "touchid"
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        }
    }
}

// MARK: - Sensitive Content Types

enum SensitiveContentType: String, CaseIterable {
    case creditCard = "Credit Card"
    case ssn = "Social Security Number"
    case credentials = "Credentials"
    case apiKey = "API Key"
    case privateKey = "Private Key"
    case phoneNumber = "Phone Number"
    case bankAccount = "Bank Account"

    var severity: Int {
        switch self {
        case .privateKey: return 5
        case .creditCard, .ssn, .bankAccount: return 4
        case .credentials, .apiKey: return 3
        case .phoneNumber: return 1
        }
    }
}

// MARK: - Sensitive Content Result

struct SensitiveContentResult {
    let isSensitive: Bool
    let types: [SensitiveContentType]
    let confidence: Double

    var highestSeverity: Int {
        types.map { $0.severity }.max() ?? 0
    }

    var shouldAutoDelete: Bool {
        highestSeverity >= 3
    }

    var description: String {
        if types.isEmpty {
            return "No sensitive content detected"
        }
        return "Detected: " + types.map { $0.rawValue }.joined(separator: ", ")
    }
}

// MARK: - Secure String

/// A string wrapper that zeros out memory on deallocation
final class SecureString {
    private var storage: [UInt8]

    init(_ string: String) {
        self.storage = Array(string.utf8)
    }

    var string: String {
        String(bytes: storage, encoding: .utf8) ?? ""
    }

    deinit {
        // Zero out the memory
        for i in 0..<storage.count {
            storage[i] = 0
        }
    }
}
