import SwiftUI

/// Test harness for the puck pairing + verification flow.
///
/// This is throwaway UI — its only job is to prove the NFC half works on real
/// hardware before any of the FamilyControls blocking logic exists. The
/// pair/verify logic here is the same shape the real unlock flow will use.
struct ContentView: View {

    /// Survives app restarts, so you can pair once and verify on a later launch.
    @AppStorage("pairedPuckUID") private var pairedPuckUID: String = ""

    @State private var reader = AnchorNFCReader()
    @State private var lastScannedUID: String?
    @State private var status: Status = .idle

    enum Status {
        case idle
        case match
        case mismatch
        case error(String)
    }

    var body: some View {
        VStack(spacing: 24) {

            Text("Anchor")
                .font(.largeTitle.bold())

            resultCard

            VStack(spacing: 12) {
                Button(action: scan) {
                    Text("Scan Puck")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let uid = lastScannedUID, uid != pairedPuckUID {
                    Button("Pair This Puck") {
                        pairedPuckUID = uid
                        status = .match
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }

                if !pairedPuckUID.isEmpty {
                    Button("Forget Paired Puck", role: .destructive) {
                        pairedPuckUID = ""
                        lastScannedUID = nil
                        status = .idle
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(28)
    }

    @ViewBuilder
    private var resultCard: some View {
        VStack(spacing: 8) {
            switch status {
            case .idle:
                Text(pairedPuckUID.isEmpty ? "No puck paired yet" : "Ready")
                    .foregroundStyle(.secondary)
            case .match:
                Text("✅ Correct puck")
                    .foregroundStyle(.green)
            case .mismatch:
                Text("❌ Wrong puck")
                    .foregroundStyle(.red)
            case .error(let message):
                Text(message)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if let uid = lastScannedUID {
                LabeledContent("Scanned", value: uid)
                    .font(.system(.footnote, design: .monospaced))
            }
            if !pairedPuckUID.isEmpty {
                LabeledContent("Paired", value: pairedPuckUID)
                    .font(.system(.footnote, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
    }

    private func scan() {
        reader.beginScan { result in
            switch result {
            case .success(let uid):
                lastScannedUID = uid
                if pairedPuckUID.isEmpty {
                    status = .idle          // nothing to compare against yet
                } else {
                    status = uid == pairedPuckUID ? .match : .mismatch
                }

            case .failure(let error):
                lastScannedUID = nil
                switch error {
                case .cancelled:
                    status = .idle
                case .unavailable:
                    status = .error("This device can't read NFC tags.")
                case .noTagFound:
                    status = .error("Didn't catch that tag — try again.")
                case .connectionFailed, .session:
                    status = .error("Scan failed. Try again.")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
