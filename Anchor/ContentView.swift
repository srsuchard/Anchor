import FamilyControls
import SwiftUI

struct ContentView: View {

    /// The puck's UID. Survives restarts — pairing is a one-time act.
    @AppStorage("pairedPuckUID") private var pairedPuckUID: String = ""

    @StateObject private var blocker = FocusBlocker()
    @Environment(\.scenePhase) private var scenePhase

    @State private var reader = AnchorNFCReader()
    @State private var isPickerPresented = false
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle
        case wrongPuck
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch blocker.authorizationStatus {
                case .approved:
                    if pairedPuckUID.isEmpty {
                        pairingView
                    } else if blocker.isBlocking {
                        blockingView
                    } else {
                        setupView
                    }
                default:
                    authorizationView
                }
            }
            .padding(28)
            .navigationTitle("Anchor")
        }
        // A scheduled session can start while Anchor is closed, so the app has
        // to re-read shared state on every return to the foreground rather than
        // trusting what it had in memory.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { blocker.refreshFromSharedState() }
        }
    }

    // MARK: - Step 1: Screen Time permission

    private var authorizationView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hourglass")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Anchor needs Screen Time access")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("This is what lets Anchor block apps. Without it, nothing can be enforced.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = blocker.authorizationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Grant Access") {
                Task { await blocker.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    // MARK: - Step 2: Pair a puck

    private var pairingView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Pair your puck")
                .font(.title2.bold())

            Text("Hold your phone to the puck. Anchor remembers it as the only thing that can unlock a focus session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            statusText

            Button("Scan Puck") { scan(intent: .pair) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
    }

    // MARK: - Step 3: Choose apps and start

    private var setupView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text(blocker.hasSelection ? "Ready to focus" : "Choose what to block")
                .font(.title2.bold())

            if blocker.hasSelection {
                Text("\(blocker.selection.applicationTokens.count) apps, \(blocker.selection.categoryTokens.count) categories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            statusText

            Button(blocker.hasSelection ? "Edit Selection" : "Choose Apps") {
                isPickerPresented = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button("Start Focus") { blocker.startBlocking() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!blocker.hasSelection)

            scheduleSection

            Button("Forget Paired Puck", role: .destructive) {
                pairedPuckUID = ""
                status = .idle
            }
            .font(.footnote)
            Spacer()
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $blocker.selection)
    }

    // MARK: - Step 4: Blocked — puck is the only way out

    private var blockingView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Focus is on")
                .font(.title2.bold())

            Text("Tap your Anchor puck to unlock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            statusText

            Button("Tap Puck to Unlock") { scan(intent: .unlock) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
    }

    // MARK: - Daily schedule

    private var scheduleSection: some View {
        VStack(spacing: 8) {
            Toggle("Repeat daily", isOn: Binding(
                get: { blocker.scheduleEnabled },
                set: { $0 ? blocker.enableSchedule() : blocker.disableSchedule() }
            ))
            .disabled(!blocker.hasSelection)

            HStack {
                Picker("From", selection: $blocker.scheduleStartHour) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
                Picker("To", selection: $blocker.scheduleEndHour) {
                    ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                }
            }
            .pickerStyle(.menu)

            if let error = blocker.scheduleError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("A scheduled session ends on its own. The puck is for unlocking early.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }

    @ViewBuilder
    private var statusText: some View {
        switch status {
        case .idle:
            EmptyView()
        case .wrongPuck:
            Text("❌ That's not your puck.")
                .foregroundStyle(.red)
        case .error(let message):
            Text(message)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Scanning

    private enum ScanIntent {
        case pair
        case unlock
    }

    private func scan(intent: ScanIntent) {
        reader.beginScan { result in
            Task { @MainActor in
                switch result {
                case .success(let uid):
                    switch intent {
                    case .pair:
                        pairedPuckUID = uid
                        status = .idle
                    case .unlock:
                        if uid == pairedPuckUID {
                            blocker.stopBlocking()
                            status = .idle
                        } else {
                            status = .wrongPuck
                        }
                    }

                case .failure(let error):
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
}

#Preview {
    ContentView()
}
