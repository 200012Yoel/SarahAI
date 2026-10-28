import SwiftUI
import WatchConnectivity
import CoreImage.CIFilterBuiltins

/// Sarah IA Watch - première application compagnon.
@main
struct SarahWatchApp: App {
    @StateObject private var link = SarahWatchLink()

    var body: some Scene {
        WindowGroup {
            SarahWatchHome()
                .environmentObject(link)
        }
    }
}

final class SarahWatchLink: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var paired = UserDefaults.standard.bool(forKey: "sarah.watch.paired")
    @Published private(set) var status = "Ouvre Sarah sur l’iPhone pour connecter la montre."
    @Published private(set) var busy = false
    @Published private(set) var code: String

    override init() {
        let stored = UserDefaults.standard.string(forKey: "sarah.watch.token")
        let token = stored ?? UUID().uuidString
        code = "sarahia-watch://pair?v=1&token=\(token)"
        UserDefaults.standard.set(token, forKey: "sarah.watch.token")
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func reconnect() {
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: "sarah.watch.token")
        UserDefaults.standard.set(false, forKey: "sarah.watch.paired")
        paired = false
        code = "sarahia-watch://pair?v=1&token=\(token)"
        status = "Scanne ce code depuis Sarah IA."
    }

    func startTranslation() {
        guard paired else {
            status = "Connecte d’abord la montre."
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            status = "iPhone indisponible. Ouvre Sarah IA sur l’iPhone."
            return
        }
        busy = true
        status = "Demande envoyée à Sarah…"
        session.sendMessage(["type": "startTranslation"], replyHandler: { [weak self] answer in
            DispatchQueue.main.async {
                self?.busy = false
                if answer["accepted"] as? Bool == true {
                    self?.status = (answer["needsForeground"] as? Bool == true)
                        ? "Ouvre Sarah sur l’iPhone pour commencer la traduction."
                        : "Demande reçue. Traduction ouverte sur l’iPhone."
                } else {
                    self?.status = answer["error"] as? String ?? "La traduction n’a pas pu être demandée."
                }
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.busy = false
                self?.status = "Connexion momentanément indisponible. Réessaie."
            }
        })
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Le QR reste disponible même si l’iPhone n’est pas encore joignable.
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["type"] as? String == "pair",
              let candidate = message["token"] as? String,
              let expected = UserDefaults.standard.string(forKey: "sarah.watch.token"),
              candidate == expected else {
            replyHandler(["ok": false, "error": "Code incorrect ou expiré"])
            return
        }
        // Appairage visuel supplémentaire. La liaison effective est garantie par watchOS.
        UserDefaults.standard.set(true, forKey: "sarah.watch.paired")
        DispatchQueue.main.async {
            self.paired = true
            self.status = "Apple Watch connectée à Sarah IA !"
        }
        replyHandler(["ok": true])
    }
}

private struct SarahWatchHome: View {
    @EnvironmentObject private var link: SarahWatchLink
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [.blue.opacity(0.23), .black], center: .center,
                           startRadius: 8, endRadius: 160)
                .ignoresSafeArea()

            if !revealed {
                VStack(spacing: 12) {
                    SarahOrb()
                        .frame(width: 58, height: 58)
                    Text("Sarah IA")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 7) {
                            SarahOrb().frame(width: 23, height: 23)
                            Text("Sarah IA")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)

                        if link.paired {
                            Label("Connectée", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                            Button {
                                link.startTranslation()
                            } label: {
                                Label(link.busy ? "Connexion…" : "Traduction", systemImage: "waveform")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(link.busy)
                            Text("Hébreu → français sur iPhone")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.gray)
                            Button("Réassocier") { link.reconnect() }
                                .font(.caption2)
                                .tint(.gray)
                        } else {
                            Text("Connecter l’iPhone")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                            WatchQRView(value: link.code)
                                .frame(width: 132, height: 132)
                                .padding(7)
                                .background(.white, in: RoundedRectangle(cornerRadius: 15))
                                .accessibilityLabel("QR code Sarah IA à scanner avec l’iPhone")
                            Text("Sarah IA → Connecter Apple Watch → Scanner")
                                .font(.system(size: 10))
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                        }
                        Text(link.status)
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.8)) {
                revealed = true
            }
        }
    }
}

private struct SarahOrb: View {
    @State private var glowing = false
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.48), lineWidth: 1)
                .scaleEffect(glowing ? 1.13 : 0.89)
            Circle()
                .fill(RadialGradient(colors: [.cyan, .blue, .indigo],
                                     center: .topLeading, startRadius: 1, endRadius: 32))
                .padding(5)
                .shadow(color: .cyan.opacity(0.7), radius: glowing ? 12 : 4)
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

private struct WatchQRView: View {
    let value: String

    var body: some View {
        Group {
            if let image = qrImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.black)
            }
        }
        .padding(4)
        .background(.white)
    }

    private var qrImage: CGImage? {
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(value.utf8)
        generator.correctionLevel = "H"
        guard let output = generator.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
