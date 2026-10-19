import SwiftUI

struct TransferQueueView: View {
    @ObservedObject var queue = ContainerTransferQueue.shared
    @ObservedObject var installer = ContainerInstaller.shared
    @ObservedObject var replacement = ContainerInstaller.shared.installReplaceAlert
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if replacement.show {
                    Section("Choose how to install this app") {
                        Text("lc.appList.installReplaceTip".loc).font(.footnote)
                        ForEach(installer.installOptions, id: \.self) { option in
                            Button(role: option.isReplace ? .destructive : nil) {
                                replacement.close(result: option)
                            } label: {
                                Text(option.isReplace ? "Replace \(option.appToReplace?.appInfo.displayName() ?? option.nameOfFolderToInstall)" : "lc.appList.installAsNew".loc)
                            }
                        }
                        Button("lc.appList.abortInstallation".loc, role: .cancel) { replacement.close(result: nil) }
                    }
                }
                Section {
                    Text("Keep browsing while up to three IPAs download. Installations run one at a time. Downloads can continue while iOS backgrounds the app; reopen the manager to finish pending installations. Force-quitting can interrupt downloads.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error = queue.storageError { Text(error).foregroundStyle(.red) }
                if queue.items.isEmpty { Text("No downloads yet.").foregroundStyle(.secondary) }
                ForEach(queue.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name.isEmpty ? "IPA download" : item.name).font(.headline)
                        Text("\(item.destination == .liveContainer ? "LiveContainer" : "Device") · \(item.state.title)")
                            .font(.subheadline).foregroundStyle(.secondary)
                        if item.state == .downloading {
                            if let progress = item.progress { ProgressView(value: progress) }
                            else { ProgressView() }
                            Text(ByteCountFormatter.string(fromByteCount: item.received, countStyle: .file)
                                 + (item.expected > 0 ? " / " + ByteCountFormatter.string(fromByteCount: item.expected, countStyle: .file) : " downloaded"))
                                .font(.caption).monospacedDigit()
                        }
                        if item.state == .installing {
                            if item.destination == .liveContainer { ProgressView(value: installer.installProgressPercentage) }
                            else { ProgressView() }
                        }
                        if let message = item.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                        if item.state == .failed {
                            Button("Retry") { queue.retry(item.id) }
                            Button("Remove download", role: .destructive) { queue.cancel(item.id) }
                        } else if item.state.isActive && item.state != .installing {
                            Button("Cancel", role: .destructive) { queue.cancel(item.id) }
                        }
                    }.padding(.vertical, 4).buttonStyle(.borderless)
                }
                Button("Clear finished downloads") { queue.clearFinished() }
            }
            .navigationTitle("Downloads")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.navigationViewStyle(.stack)
    }
}

struct TransferQueuePresenter: ViewModifier {
    @ObservedObject var queue = ContainerTransferQueue.shared
    @ObservedObject var installer = ContainerInstaller.shared
    @ObservedObject var replacement = ContainerInstaller.shared.installReplaceAlert

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !queue.items.isEmpty || queue.storageError != nil {
                    Button { queue.showQueue = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: queue.failedCount > 0 ? "exclamationmark.arrow.triangle.2.circlepath" : "arrow.down.circle")
                            Text(replacement.show ? "Download ready · choose installation option" : (queue.activeCount > 0 ? "Downloads · \(queue.activeCount) active" : "Downloads"))
                            Spacer()
                            if queue.failedCount > 0 { Text("\(queue.failedCount) need attention").font(.caption) }
                            Image(systemName: "chevron.right").font(.caption)
                        }.font(.subheadline).padding(.horizontal).padding(.vertical, 8)
                            .background(.regularMaterial)
                    }.buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $queue.showQueue) { TransferQueueView() }
    }
}
