import AppKit
import UserNotifications

/// Posts a notification when an agent starts needing you (and optionally when one finishes).
/// Clicking it jumps to that agent's terminal.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let store: AgentStore
    private var center: UNUserNotificationCenter { .current() }
    private var authorized = false

    init(store: AgentStore) {
        self.store = store
        super.init()
        center.delegate = self
        store.onTransition = { [weak self] agent, from in self?.transition(agent, from: from) }
    }

    private func transition(_ agent: Agent, from: AgentState) {
        let settings = Settings.shared
        switch agent.state {
        case .waiting where settings.notifyWaiting:
            post(agent, title: "\(agent.project) needs you", body: agent.detail?.isEmpty == false ? agent.detail! : agent.displayTitle)
        case .ready where settings.notifyReady && from == .working:
            post(agent, title: "\(agent.project) is ready", body: agent.displayTitle)
        default:
            // Resolved elsewhere (answered in the terminal): pull the stale banner.
            if from == .waiting { center.removeDeliveredNotifications(withIdentifiers: [agent.id]) }
        }
    }

    private func post(_ agent: Agent, title: String, body: String) {
        authorize { [weak self] ok in
            guard ok, let self else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = agent.kind.displayName
            content.body = body
            content.userInfo = ["pid": Int(agent.pid)]
            content.threadIdentifier = "barn.\(agent.id)"
            if Settings.shared.notificationSound { content.sound = .default }
            // Same identifier per agent: a new prompt replaces the old banner instead of stacking.
            self.center.add(UNNotificationRequest(identifier: agent.id, content: content, trigger: nil))
        }
    }

    private func authorize(_ then: @escaping (Bool) -> Void) {
        if authorized { return then(true) }
        center.requestAuthorization(options: [.alert, .sound]) { ok, error in
            if let error { Log.write("notifications: \(error)") }
            DispatchQueue.main.async {
                self.authorized = ok
                then(ok)
            }
        }
    }

    // Show banners even though barn is technically "active" after a click.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completion: @escaping () -> Void) {
        let pid = response.notification.request.content.userInfo["pid"] as? Int
        DispatchQueue.main.async {
            if let pid, let agent = self.store.agents.first(where: { $0.pid == pid_t(pid) }) {
                self.store.acknowledge(agent)
                Focus.open(agent)
            }
            completion()
        }
    }
}
