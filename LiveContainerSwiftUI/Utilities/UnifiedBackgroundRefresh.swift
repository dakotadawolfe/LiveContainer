import BackgroundTasks
import SideStoreSupport

@MainActor
enum UnifiedBackgroundRefresh {
    static let identifier = "com.kdt.livecontainer.unified-refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            let work = Task { @MainActor in
                schedule()
                await UnifiedRefreshCoordinator.shared.foregroundOpportunity()
                // This acknowledges the opportunity, not a verified installation.
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        guard UnifiedRefreshCoordinator.shared.policy != .manual else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        // iOS can decline or defer this request. Foreground and Shortcuts remain available.
        try? BGTaskScheduler.shared.submit(request)
    }
}
