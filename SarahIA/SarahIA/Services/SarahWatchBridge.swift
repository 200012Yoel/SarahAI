import Foundation
import SwiftUI
import AVFoundation
import UIKit
import WatchConnectivity

/// Transport entre les DEUX apps officielles Sarah IA, sans serveur ni compte.
final class SarahPhoneWatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = SarahPhoneWatchBridge()
    @Published private(set) var paired = UserDefaults.standard.bool(forKey: "sarah.watch.connected")

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func pair(scanned text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: text),
              url.scheme == "sarahia-watch",
              url.host == "pair",
              let params = URLComponents(url: url, resolvingAgainstBaseURL: false),
              params.queryItems?.first(where: { $0.name == "v" })?.value == "1",
              let token = params.queryItems?.first(where: { $0.name == "token" })?.value,
              UUID(uuidString: token) != nil else {
            completion(.failure(WatchConnectionError.invalidCode))
            return
        }
        guard WCSession.isSupported() else {
            completion(.failure(WatchConnectionError.notSupported))
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled, session.isReachable else {
            completion(.failure(WatchConnectionError.notReachable))
            return
        }
        // Le token n'est validé que par l'app fonctionnant sur la montre appairée par iOS.
        session.sendMessage(["type": "pair", "token": token], replyHandler: { response in
            DispatchQueue.main.async {
                if response["ok"] as? Bool == true {
                    UserDefaults.standard.set(true, forKey: "sarah.watch.connected")
                    self.paired = true
                    completion(.success(()))
                } else {
                    completion(.failure(WatchConnectionError.mismatchedCode))
                }
            }
        }, errorHandler: { _ in
            DispatchQueue.main.async {
                completion(.failure(WatchConnectionError.notReachable))
            }
        })
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Un changement de montre invalide l'accord visuel précédent.
        if !session.isPaired || !session.isWatchAppInstalled {
            DispatchQueue.main.async {
                self.paired = false
                UserDefaults.standard.set(false, forKey: "sarah.watch.connected")
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["type"] as? String == "startTranslation" else {
            replyHandler(["accepted": false, "error": "Commande inconnue"])
            return
        }
        guard UserDefaults.standard.bool(forKey: "sarah.watch.connected") else {
            replyHandler(["accepted": false, "error": "Scanne d’abord le QR code"])
            return
        }

        // L'app watchOS peut réveiller le processus iOS, PAS ouvrir l'interface iPhone.
        // Préparer la demande, puis démarrer le micro UNIQUEMENT après ouverture visible.
        let isVisible = UIApplication.shared.applicationState == .active
        if !isVisible {
            UserDefaults.standard.set(true, forKey: "sarah.watch.pendingTranslation")
        }
        replyHandler(["accepted": true, "needsForeground": !isVisible])
        if isVisible {
            DispatchQueue.main.async {
                SarahActionCoordinator.shared.dispatch(.openLiveTranslation)
            }
        }
    }

    static func consumePendingTranslation() -> Bool {
        guard UserDefaults.standard.bool(forKey: "sarah.watch.pendingTranslation") else {
            return false
        }
        UserDefaults.standard.set(false, forKey: "sarah.watch.pendingTranslation")
        return true
    }
}

private enum WatchConnectionError: LocalizedError {
    case invalidCode, notSupported, notReachable, mismatchedCode

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Ce code ne vient pas de Sarah IA Watch."
        case .notSupported: return "Watch Connectivity n'est pas disponible."
        case .notReachable: return "Ouvre Sarah IA sur la montre et rapproche-la de l’iPhone."
        case .mismatchedCode: return "Le code ne correspond pas à celui affiché sur la montre."
        }
    }
}

@available(iOS 15.0, *)
struct SarahWatchPairingView: View {
    @StateObject private var bridge = SarahPhoneWatchBridge.shared
    @Environment(\.dismiss) private var dismiss
    @State private var permissionGranted = false
    @State private var scanning = false
    @State private var inFlight = false
    @State private var message = "Ouvre Sarah IA sur ta montre et affiche son QR code."
    @State private var connectedNow = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.16))
                            .frame(width: 90, height: 90)
                        Image(systemName: "applewatch")
                            .font(.system(size: 42))
                            .foregroundColor(.cyan)
                    }
                    Text("Connecter Apple Watch")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Scanne le QR code de Sarah affiché sur ta montre.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    if connectedNow {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Apple Watch connectée")
                            .font(.headline)
                            .foregroundColor(.white)
                        Button("Terminé") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    } else if scanning && permissionGranted {
                        SarahWatchQRCodeScanner { value in
                            guard !inFlight else { return }
                            inFlight = true
                            bridge.pair(scanned: value) { result in
                                inFlight = false
                                switch result {
                                case .success:
                                    connectedNow = true
                                    scanning = false
                                    message = "Association confirmée par la montre."
                                case .failure(let error):
                                    message = error.localizedDescription
                                }
                            }
                        }
                        .frame(height: 290)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                        }
                        Button("Arrêter le scan") { scanning = false }
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 78))
                            .foregroundColor(.cyan)
                            .frame(height: 140)
                        Button("Scanner le QR code") { requestCamera() }
                            .buttonStyle(.borderedProminent)
                    }

                    Text(message)
                        .foregroundColor(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                    Text("La montre et l’iPhone doivent déjà être jumelés dans l’app Watch. Le QR ajoute une confirmation dans Sarah IA.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(22)
            }
        }
        .navigationTitle("Apple Watch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            scanning = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    permissionGranted = ok
                    scanning = ok
                    if !ok { message = "Autorise la caméra dans Réglages pour scanner le code." }
                }
            }
        default:
            message = "Autorise la caméra pour Sarah IA dans Réglages iOS."
        }
    }
}

@available(iOS 15.0, *)
private struct SarahWatchQRCodeScanner: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeUIView(context: Context) -> ScannerPreview {
        let view = ScannerPreview()
        let session = AVCaptureSession()
        context.coordinator.session = session
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return view }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ uiView: ScannerPreview, context: Context) {}

    func dismantleUIView(_ uiView: ScannerPreview, coordinator: Coordinator) {
        let session = coordinator.session
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var session: AVCaptureSession?
        let onScan: (String) -> Void
        private var lastValue = ""
        private var lastScan = Date.distantPast

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,
                  code != lastValue || Date().timeIntervalSince(lastScan) > 2 else { return }
            lastValue = code
            lastScan = Date()
            onScan(code)
        }
    }

    final class ScannerPreview: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
