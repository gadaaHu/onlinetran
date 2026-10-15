import SwiftUI
import WebKit
import AVFoundation
import Vision

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Face Detection Camera Manager
// ─────────────────────────────────────────────────────────────────────────────
class FaceDetectionManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var faceCount: Int = 0
    @Published var faceBoxes: [CGRect] = []
    @Published var isRunning: Bool = false

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.eduverse.facedetection")
    private var lastAnalysisTime: Date = .distantPast
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // Vision face detection request
    private lazy var faceRequest: VNDetectFaceRectanglesRequest = {
        let req = VNDetectFaceRectanglesRequest { [weak self] req, err in
            guard let self = self else { return }
            let results = req.results as? [VNFaceObservation] ?? []
            DispatchQueue.main.async {
                self.faceCount = results.count
                self.faceBoxes = results.map { $0.boundingBox }
            }
        }
        req.revision = VNDetectFaceRectanglesRequestRevision3
        return req
    }()

    func start() {
        guard !isRunning else { return }
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        queue.async {
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stop() {
        queue.async {
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle to ~10 fps for performance
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisTime) > 0.1 else { return }
        lastAnalysisTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored,
                                            options: [:])
        try? handler.perform([faceRequest])
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Camera Preview + Face Bounding Box Overlay (UIViewRepresentable)
// ─────────────────────────────────────────────────────────────────────────────
struct FaceCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var faceBoxes: [CGRect]

    func makeUIView(context: Context) -> FaceCameraUIView {
        let v = FaceCameraUIView()
        v.setupPreview(session: session)
        return v
    }

    func updateUIView(_ uiView: FaceCameraUIView, context: Context) {
        uiView.updateFaces(faceBoxes)
    }
}

class FaceCameraUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var overlayLayer = CALayer()

    func setupPreview(session: AVCaptureSession) {
        backgroundColor = UIColor(red: 8/255, green: 8/255, blue: 20/255, alpha: 1)
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        self.previewLayer = preview
        overlayLayer.frame = bounds
        layer.addSublayer(overlayLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
        overlayLayer.frame = bounds
    }

    func updateFaces(_ boxes: [CGRect]) {
        overlayLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        for box in boxes {
            // Vision coords: origin is bottom-left, Y flipped
            let converted = CGRect(
                x: box.origin.x * bounds.width,
                y: (1 - box.origin.y - box.height) * bounds.height,
                width: box.width * bounds.width,
                height: box.height * bounds.height
            )

            // Bounding box
            let borderLayer = CALayer()
            borderLayer.frame = converted
            borderLayer.borderColor = UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 0.9).cgColor
            borderLayer.borderWidth = 3
            borderLayer.cornerRadius = 6
            overlayLayer.addSublayer(borderLayer)

            // Label
            let label = CATextLayer()
            label.string = "Face"
            label.fontSize = 12
            label.foregroundColor = UIColor.white.cgColor
            label.backgroundColor = UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 0.75).cgColor
            label.cornerRadius = 4
            label.frame = CGRect(x: converted.minX, y: converted.minY - 20, width: 44, height: 20)
            label.isWrapped = false
            label.alignmentMode = .center
            label.contentsScale = UIScreen.main.scale
            overlayLayer.addSublayer(label)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Face Detection Panel View
// ─────────────────────────────────────────────────────────────────────────────
struct FaceDetectionPanel: View {
    @StateObject private var manager = FaceDetectionManager()
    let isInstructor: Bool
    var onFaceCountChanged: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                HStack(spacing: 6) {
                    Text("🔍")
                        .font(.system(size: 14))
                    Text("Face Detection")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                // Face count badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.faceCount > 0 ? Color(red: 16/255, green: 185/255, blue: 129/255)
                                                     : Color(red: 239/255, green: 68/255, blue: 68/255))
                        .frame(width: 7, height: 7)
                    Text(manager.faceCount > 0
                         ? "\(manager.faceCount) face\(manager.faceCount > 1 ? "s" : "")"
                         : "No face")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(manager.faceCount > 0
                                         ? Color(red: 16/255, green: 185/255, blue: 129/255)
                                         : Color(red: 239/255, green: 68/255, blue: 68/255))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(manager.faceCount > 0
                              ? Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.2)
                              : Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.2))
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 15/255, green: 15/255, blue: 29/255))

            // Camera preview with face box overlay
            ZStack {
                if manager.isRunning {
                    FaceCameraPreview(session: manager.session, faceBoxes: manager.faceBoxes)

                    // Role label overlay
                    VStack {
                        HStack {
                            Text(isInstructor ? "🎓 Instructor Camera" : "🎓 Student Camera")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                            Spacer()
                        }
                        .padding(8)
                        Spacer()

                        // No-face warning banner
                        if manager.faceCount == 0 {
                            HStack {
                                Spacer()
                                Text("⚠️  Face not visible — stay in frame")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            .background(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.8))
                        }
                    }
                } else {
                    Color(red: 15/255, green: 15/255, blue: 29/255)
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Starting camera...")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .onAppear {
            manager.start()
        }
        .onDisappear {
            manager.stop()
        }
        .onChange(of: manager.faceCount) { count in
            onFaceCountChanged(count)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Live Classroom View (updated)
// ─────────────────────────────────────────────────────────────────────────────
struct LiveClassroomView: View {
    @Environment(\.dismiss) var dismiss
    let roomName: String
    let lessonTitle: String

    @State private var isHandRaised: Bool = false
    @State private var reactions: [FloatingEmoji] = []
    @State private var faceCount: Int = 0

    private var isInstructor: Bool {
        APIService.shared.currentUser?.roles?.contains(where: {
            $0.lowercased() == "instructor" || $0.lowercased() == "admin"
        }) ?? false
    }

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

                    // Face count indicator in header
                    HStack(spacing: 4) {
                        Text("👤")
                            .font(.system(size: 11))
                        Text(faceCount > 0 ? "\(faceCount)" : "0")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(faceCount > 0
                                ? Color(red: 16/255, green: 185/255, blue: 129/255)
                                : Color(red: 239/255, green: 68/255, blue: 68/255))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)

                    Button(action: { dismiss() }) {
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

                // ── Main Jitsi WebRTC Video (top 58%)
                SwiftUIWebView(url: jitsiURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.38)

                // ── Face Detection Panel (bottom area)
                FaceDetectionPanel(isInstructor: isInstructor) { count in
                    faceCount = count
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Interactive Dock
                HStack {
                    Button(action: { isHandRaised.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 13))
                            Text(isHandRaised ? "Hand Raised" : "Raise Hand")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isHandRaised ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isHandRaised
                            ? Color(red: 245/255, green: 158/255, blue: 11/255)
                            : Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(["👏", "❤️", "💡", "🔥"], id: \.self) { emoji in
                            Button(action: { triggerReaction(emoji) }) {
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
