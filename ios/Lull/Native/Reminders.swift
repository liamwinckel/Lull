import UserNotifications

/// A gentle nightly nudge that opens straight into "Drift to sleep".
enum Reminders {
    static func set(on: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["nightly"])
        guard on else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time to wind down?"
            content.body = "Drift to sleep is ready when you are."
            content.sound = .default
            content.userInfo = ["session": "sleep"]
            var when = DateComponents(); when.hour = hour; when.minute = minute
            let req = UNNotificationRequest(identifier: "nightly", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
            center.add(req)
        }
    }
}
