import SwiftUI
import WebKit

struct LiveClassroomView: View {
    @Environment(\.dismiss) var dismiss
    let roomName: String
    let lessonTitle: String

    @State private var isHandRaised: Bool = false
    @State private var reactions: [FloatingEmoji] = []

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 20/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Custom Header
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 239/255, green: 68/255, blue: 68/255))
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.15))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lessonTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("Room: \(roomName)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.leading, 6)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 11))
                            Text("Leave")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 239/255, green: 68/255, blue: 68/255))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 15/255, green: 15/255, blue: 29/255))

                // Embedded WebRTC Video Stage
                SwiftUIWebView(url: jitsiURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Interactive Floating Dock
                HStack {
                    // Hand Raise Toggle
                    Button(action: {
                        isHandRaised.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 13))
                            Text(isHandRaised ? "Hand Raised" : "Raise Hand")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isHandRaised ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHandRaised ? Color(red: 245/255, green: 158/255, blue: 11/255) : Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }

                    Spacer()

                    // Quick Reactions Row
                    HStack(spacing: 6) {
                        ForEach(["👏", "❤️", "💡", "🔥"], id: \.self) { emoji in
                            Button(action: {
                                triggerReaction(emoji)
                            }) {
                                Text(emoji)
                                    .font(.system(size: 16))
                                    .padding(6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 19/255, green: 19/255, blue: 38/255))
            }

            // Floating Animated Reactions
            ForEach(reactions) { item in
                Text(item.emoji)
                    .font(.system(size: 32))
                    .position(x: item.x, y: item.y)
                    .opacity(item.opacity)
            }
        }
    }

    private var jitsiURL: URL {
        let name = APIService.shared.currentUser?.fullName ?? "iOS Student"
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Student"
        let str = "https://meet.jit.si/\(roomName)#config.startWithAudioMuted=false&config.startWithVideoMuted=false&config.prejoinPageEnabled=false&userInfo.displayName=\(encoded)"
        return URL(string: str)!
    }

    private func triggerReaction(_ emoji: String) {
        let newX = CGFloat.random(in: 80...300)
        let reaction = FloatingEmoji(emoji: emoji, x: newX, y: 550, opacity: 1.0)
        reactions.append(reaction)

        withAnimation(.easeOut(duration: 1.8)) {
            if let index = reactions.firstIndex(where: { $0.id == reaction.id }) {
                reactions[index].y -= 250
                reactions[index].opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            reactions.removeAll(where: { $0.id == reaction.id })
        }
    }
}

struct FloatingEmoji: Identifiable {
    let id = UUID()
    let emoji: String
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
}

struct SwiftUIWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(red: 10/255, green: 10/255, blue: 20/255, alpha: 1)
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
