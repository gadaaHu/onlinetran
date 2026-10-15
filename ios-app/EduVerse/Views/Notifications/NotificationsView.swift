import SwiftUI

// MARK: - Model
struct AppNotification: Identifiable, Decodable {
    let id: Int
    let title: String
    let message: String
    let type: String
    let isRead: Bool
    let actionUrl: String?
    let createdAt: String

    var isReadMutable: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, title, message, type, isRead, actionUrl, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(Int.self,    forKey: .id)
        title     = try c.decode(String.self, forKey: .title)
        message   = try c.decode(String.self, forKey: .message)
        type      = try c.decode(String.self, forKey: .type)
        isRead    = try c.decode(Bool.self,   forKey: .isRead)
        actionUrl = try c.decodeIfPresent(String.self, forKey: .actionUrl)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        isReadMutable = isRead
    }
}

// MARK: - View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var unreadOnly = false
    @State private var errorMessage: String?

    private var baseURL: String { APIService.shared.rootURL }

    var unreadCount: Int { notifications.filter { !$0.isReadMutable }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A").ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "6366F1")))
                        .scaleEffect(1.5)
                } else if let err = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                        Text(err)
                            .foregroundColor(.white.opacity(0.7))
                        Button("Retry") { loadNotifications() }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "6366F1"))
                    }
                } else if notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "6366F1"))
                        Text("No notifications")
                            .font(.headline).foregroundColor(.white)
                        Text(unreadOnly ? "You're all caught up!" : "Notifications appear here")
                            .font(.subheadline).foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach($notifications) { $notif in
                                NotificationCard(notification: $notif) {
                                    markRead(id: notif.id)
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity))
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(hex: "0F0F1A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if unreadCount > 0 {
                            Button("Mark all read") { markAllRead() }
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color(hex: "6366F1"))
                        }
                        Button(action: { loadNotifications() }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPillView(label: "All", selected: !unreadOnly) {
                            unreadOnly = false; loadNotifications()
                        }
                        FilterPillView(label: "Unread (\(unreadCount))", selected: unreadOnly) {
                            unreadOnly = true; loadNotifications()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(hex: "0F0F1A"))
            }
            .onAppear { loadNotifications() }
        }
    }

    // MARK: - API
    func loadNotifications() {
        isLoading = true
        errorMessage = nil
        guard let token = UserDefaults.standard.string(forKey: "auth_token"),
              let url = URL(string: "\(baseURL)/api/notifications?unreadOnly=\(unreadOnly)&pageSize=50")
        else { isLoading = false; return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        URLSession.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription; return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let arr = json["notifications"] as? [[String: Any]],
                      let arrData = try? JSONSerialization.data(withJSONObject: arr)
                else { return }
                if let decoded = try? JSONDecoder().decode([AppNotification].self, from: arrData) {
                    withAnimation { notifications = decoded }
                }
            }
        }.resume()
    }

    func markRead(id: Int) {
        guard let token = UserDefaults.standard.string(forKey: "auth_token"),
              let url = URL(string: "\(baseURL)/api/notifications/\(id)/read")
        else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                if let idx = notifications.firstIndex(where: { $0.id == id }) {
                    notifications[idx].isReadMutable = true
                }
            }
        }.resume()
    }

    func markAllRead() {
        guard let token = UserDefaults.standard.string(forKey: "auth_token"),
              let url = URL(string: "\(baseURL)/api/notifications/read-all")
        else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                withAnimation { notifications = notifications.map { var n = $0; n.isReadMutable = true; return n } }
            }
        }.resume()
    }
}

// MARK: - Card
struct NotificationCard: View {
    @Binding var notification: AppNotification
    let onMarkRead: () -> Void

    var typeColor: Color {
        switch notification.type {
        case "success": return Color(hex: "10B981")
        case "warning": return Color(hex: "F59E0B")
        case "live":    return Color(hex: "EF4444")
        default:        return Color(hex: "6366F1")
        }
    }

    var typeIcon: String {
        switch notification.type {
        case "success": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "live":    return "video.fill"
        default:        return "bell.fill"
        }
    }

    var body: some View {
        let isRead = notification.isReadMutable
        Button(action: { if !isRead { onMarkRead() } }) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(typeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: typeIcon)
                        .foregroundColor(typeColor)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline.weight(isRead ? .regular : .bold))
                            .foregroundColor(isRead ? .white.opacity(0.6) : .white)
                        Spacer()
                        if !isRead {
                            Circle()
                                .fill(typeColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(isRead ? .white.opacity(0.35) : .white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(timeAgo(notification.createdAt))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.28))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: isRead ? "1A1A2E" : "1E1E3F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isRead ? Color.white.opacity(0.05) : typeColor.opacity(0.35), lineWidth: isRead ? 1 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func timeAgo(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: iso) else { return "" }
        let mins = Int(Date().timeIntervalSince(date) / 60)
        switch mins {
        case ..<1:    return "just now"
        case ..<60:   return "\(mins)m ago"
        case ..<1440: return "\(mins/60)h ago"
        default:      return "\(mins/1440)d ago"
        }
    }
}

// MARK: - Filter Pill
struct FilterPillView: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selected ? Color(hex: "6366F1") : Color(hex: "1E1E2E"))
                        .overlay(
                            Capsule()
                                .stroke(selected ? Color(hex: "6366F1") : Color.white.opacity(0.1))
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}
