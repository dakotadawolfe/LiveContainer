import SwiftUI
import SideStoreSupport

struct UnifiedRefreshView: View {
    @ObservedObject private var coordinator = UnifiedRefreshCoordinator.shared
    @State private var error: String?
    var body: some View {
        NavigationView {
            List {
                Section("Manager provisioning") {
                    Text(coordinator.status)
                    if let profile = coordinator.hostProfile {
                        Text("Installed profile expires: \(profile.expires.formatted())")
                    } else {
                        Text("No readable installed provisioning profile. Complete initial signing setup.")
                    }
                    Button("Refresh Everything Now") { run { try await coordinator.refresh() } }
                        .disabled(coordinator.busy)
                    if coordinator.busy { ProgressView("Working with embedded SideStore…") }
                    Button("Reload signing records") { run { try await coordinator.synchronize() } }
                        .disabled(coordinator.busy)
                }
                Section("Automation") {
                    Picker("Refresh policy", selection: $coordinator.policy) {
                        ForEach(RefreshPolicy.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Enable expiration reminders") { run { try await coordinator.enableNotifications() } }
                    Text("In Shortcuts, create a daily Personal Automation. Connect LocalDevVPN, then run this app’s Refresh All Apps action. Choose Run Immediately if offered. Keep a foreground fallback: iOS may suspend background work, and authentication can require interaction.")
                        .font(.footnote)
                }
                Section("Device apps — SideStore signing records") {
                    ForEach(coordinator.apps) { app in
                        VStack(alignment: .leading) {
                            Text(app.name).bold()
                            Text("Expires \(app.expires.formatted())")
                            Text("Record read from SideStore; installed-device profile verification is separate.").font(.caption).foregroundStyle(.secondary)
                            Button("Refresh this app") { run { try await coordinator.refresh(bundleID: app.bundleID) } }
                                .disabled(coordinator.busy)
                        }
                    }
                }
                Section("History") {
                    ForEach(coordinator.events) { event in
                        VStack(alignment: .leading) {
                            Text(event.message)
                            Text(event.date.formatted()).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Refresh")
        }
        .navigationViewStyle(.stack)
        .alert("Refresh needs attention", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
            Button("Apple ID / Signing") { LCUtils.openSideStore() }
        } message: { Text(error ?? "") }
    }
    private func run(_ action: @escaping () async throws -> Void) {
        Task { do { try await action() } catch { self.error = error.localizedDescription } }
    }
}

struct ManagedDeviceAppsView: View {
    @ObservedObject private var coordinator = UnifiedRefreshCoordinator.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device apps").font(.title2.bold())
            if coordinator.apps.isEmpty {
                Text("Open Refresh to load managed device apps after Apple ID setup.").foregroundStyle(.secondary)
            }
            ForEach(coordinator.apps) { app in
                HStack {
                    VStack(alignment: .leading) {
                        Text(app.name).bold()
                        Text("Device · \(app.version)").font(.caption)
                        if app.expires.timeIntervalSinceNow < 48 * 3600 { Text("Refresh needed").foregroundStyle(.orange) }
                    }
                    Spacer()
                    Button("Manage") { LCUtils.openSideStore() }
                }
            }
            Text("LiveContainer guests").font(.title2.bold())
        }.padding()
    }
}
