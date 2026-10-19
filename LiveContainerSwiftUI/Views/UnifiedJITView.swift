import SwiftUI
import Network
import UniformTypeIdentifiers

struct UnifiedJITView: View {
    @State private var importing = false
    @State private var testing = false
    @State private var status = "Connection has not been tested."
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var method: JITEnablerType = .StikJITHeadless

    var body: some View {
        NavigationView {
            Form {
                Section("Integrated StikJIT") {
                    Toggle("Use built-in StikJIT for JIT launches", isOn: Binding(get: { method == .StikJITHeadless }, set: { if $0 { method = .StikJITHeadless } else { method = .SideJITServer } }))
                    Text("JIT-less guests retain their normal launch path. Choose the required script in each guest’s settings. Debugger attachment alone does not make every executable-memory allocator compatible with newer iOS devices.").font(.footnote)
                    Text(FileManager.default.fileExists(atPath: LCPath.pairingFilePath.path) ? "Pairing file present (device connection not yet verified)." : "Import pairing information for this device.")
                    Button("Import pairing file") { importing = true }
                    Button("Test LocalDevVPN endpoint") { testConnection() }.disabled(testing)
                    if testing { ProgressView() }
                    Text(status).font(.footnote)
                }
                Section("Requirements") {
                    Text("Enable Developer Mode, connect LocalDevVPN, and keep the LiveProcess extension when signing. The host requires get-task-allow. A successful endpoint test proves TCP reachability only; launch a compatible guest to test pairing, DDI mounting, debugger attachment, and executable memory.")
                    Link("Open LocalDevVPN on the App Store", destination: URL(string: "https://apps.apple.com/app/id6755608044")!)
                    Text("Bundling the VPN requires Apple’s Network Extension provisioning capability. The free Apple ID build uses the external App Store utility.").font(.footnote)
                }
            }.navigationTitle("JIT")
        }
        .navigationViewStyle(.stack)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.propertyList, .data]) { result in
            do { try Self.importPairing(try result.get()); status = "Pairing file imported. Test the connection and launch a compatible guest." }
            catch { status = "Pairing import failed. Select a valid pairing plist for this device." }
        }
    }

    static func importPairing(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count <= 1024 * 1024,
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["HostID"] != nil, plist["SystemBUID"] != nil,
              plist["HostPrivateKey"] != nil, plist["HostCertificate"] != nil else {
            throw NSError(domain: "Pairing", code: 1)
        }
        try FileManager.default.createDirectory(at: LCPath.pairingFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: LCPath.pairingFilePath, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func testConnection() {
        testing = true
        status = "Testing the local tunnel endpoint…"
        let connection = NWConnection(host: "10.7.0.1", port: 49152, using: .tcp)
        var completed = false
        func finish(_ message: String) {
            guard !completed else { return }
            completed = true
            connection.cancel()
            status = message
            testing = false
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: finish("Local endpoint reachable. Pairing, DDI, and JIT execution remain unverified until a guest launch.")
            case .failed: finish("Endpoint unreachable. Check LocalDevVPN, Wi-Fi, and its tunnel configuration.")
            default: break
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { finish("Connection timed out. Check LocalDevVPN and Wi-Fi.") }
    }
}
