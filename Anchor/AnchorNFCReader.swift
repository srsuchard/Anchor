import CoreNFC

/// Reads the factory UID from an NFC tag using the native iOS scan sheet.
///
/// Usage:
///   let reader = AnchorNFCReader()
///   reader.beginScan { result in
///       switch result {
///       case .success(let uid): print(uid)   // e.g. "04A23F91B2"
///       case .failure(let error): print(error)
///       }
///   }
///
/// Requires:
///   - "Near Field Communication Tag Reading" capability (Signing & Capabilities)
///   - NFCReaderUsageDescription in Info.plist
final class AnchorNFCReader: NSObject {

    enum ScanError: Error {
        case unavailable
        case noTagFound
        case connectionFailed(Error)
        case cancelled
        case session(Error)
    }

    private var session: NFCTagReaderSession?
    private var completion: ((Result<String, ScanError>) -> Void)?

    /// Presents the system NFC sheet and returns the first tag's UID as an
    /// uppercase hex string. The completion is called on the main queue.
    func beginScan(completion: @escaping (Result<String, ScanError>) -> Void) {
        guard NFCTagReaderSession.readingAvailable else {
            completion(.failure(.unavailable))
            return
        }

        self.completion = completion
        session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        )
        session?.alertMessage = "Hold your phone near the puck."
        session?.begin()
    }

    private func finish(_ result: Result<String, ScanError>) {
        let handler = completion
        completion = nil
        session = nil
        DispatchQueue.main.async { handler?(result) }
    }
}

extension AnchorNFCReader: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        // A successful read invalidates the session too — completion is already
        // nil by then, so finish() is a no-op in that case.
        guard completion != nil else { return }

        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            finish(.failure(.cancelled))
        } else {
            finish(.failure(.session(error)))
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            finish(.failure(.noTagFound))
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }

            if let error {
                session.invalidate(errorMessage: "Couldn't read the puck. Try again.")
                self.finish(.failure(.connectionFailed(error)))
                return
            }

            guard let identifier = Self.identifier(for: tag) else {
                session.invalidate(errorMessage: "Unsupported tag type.")
                self.finish(.failure(.noTagFound))
                return
            }

            let uid = identifier.map { String(format: "%02X", $0) }.joined()
            session.alertMessage = "Puck recognized."
            session.invalidate()
            self.finish(.success(uid))
        }
    }

    /// The UID lives at a different place on each tag family.
    private static func identifier(for tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let mifare):
            return mifare.identifier
        case .iso7816(let iso7816):
            return iso7816.identifier
        case .iso15693(let iso15693):
            return iso15693.identifier
        case .feliCa(let feliCa):
            return feliCa.currentIDm
        @unknown default:
            return nil
        }
    }
}
