import SwiftUI
import WebKit
import Foundation

/// Interactive, real-data worldwide map inside Sarah's chat.
/// MapLibre + OpenFreeMap vector tiles; Nominatim + Overpass are called ONLY
/// following an explicit search. All results come from the network, never mocks.
public enum SarahMapIntent {
    public static func wantsMap(_ text: String) -> Bool {
        let n = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: Locale(identifier: "fr_FR")).lowercased()
        let place = ["restaurant", "cafe", "hotel", "boutique", "commerce",
                     "aeroport", "gare", "adresse", "carte", "plan",
                     "ou se trouve", "ou est situe", "autour de moi"]
            .contains(where: { n.contains($0) })
        let seeking = ["trouv", "cherch", "montr", "affich", "voir", "ouvre",
                       "localis", "autour", "a cote", "pres de", "position", "carte",
                       "plan", "situe", "ou est", "liste"]
            .contains(where: { n.contains($0) })
        return place && seeking && n.count < 350
    }

    public static func payload(_ text: String) -> String {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "[[SARAH_MAP|query=\(encoded)]]"
    }

    public static func query(in text: String) -> String? {
        guard let start = text.range(of: "[[SARAH_MAP|query="),
              let end = text.range(of: "]]", range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.upperBound..<end.lowerBound]).removingPercentEncoding
    }
}

@available(iOS 15.0, *)
public struct SarahWorldMapCard: View {
    public let query: String
    @State private var expanded = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "globe.europe.africa.fill")
                    .foregroundColor(.cyan)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sarah · Carte du monde 3D")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Lieux réels · OpenStreetMap")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.62))
                }
                Spacer()
                Button { expanded = true } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                }
                .accessibilityLabel("Afficher la carte 3D en plein écran")
            }
            .padding(14)

            SarahWorldMapWebView(query: query)
                .frame(height: 350)
                .accessibilityIdentifier("sarah.map3d.webview")

            Text("Tourne, incline et zoome. Les bâtiments 3D dépendent des données disponibles.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
        }
        .background(Color(red: 0.075, green: 0.09, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.14)))
        .fullScreenCover(isPresented: $expanded) {
            NavigationView {
                SarahWorldMapWebView(query: query)
                    .navigationTitle("Sarah · Explorer en 3D")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Fermer") { expanded = false }
                        }
                    }
                    .background(Color.black.ignoresSafeArea())
            }
            .preferredColorScheme(.dark)
        }
    }
}

@available(iOS 15.0, *)
private struct SarahWorldMapWebView: UIViewRepresentable {
    let query: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "sarahMap")
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.035, green: 0.065, blue: 0.11, alpha: 1)
        web.scrollView.isScrollEnabled = false
        context.coordinator.web = web
        // Serialized through JSON so the search cannot inject scripts.
        let data = (try? JSONSerialization.data(withJSONObject: [query])) ?? Data("[\"\" ]".utf8)
        let encoded = String(data: data, encoding: .utf8) ?? "[\"\"]"
        let html = Self.html.replacingOccurrences(of: "__SARAH_INITIAL_QUERY__", with: encoded)
        web.loadHTMLString(html, baseURL: URL(string: "https://openfreemap.org/"))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var web: WKWebView?
        private var isLoading = false
        private var lastGeocode = Date.distantPast

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "sarahMap",
                  let input = message.body as? [String: Any],
                  let operation = input["action"] as? String,
                  operation == "search",
                  let query = input["query"] as? String,
                  !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  query.count <= 220 else { return }
            guard !isLoading else { return }
            // Public Nominatim usage policy: at most one search per second.
            guard Date().timeIntervalSince(lastGeocode) >= 1 else {
                send(["kind": "error", "message": "Attends une seconde avant une autre recherche."])
                return
            }
            lastGeocode = Date()
            isLoading = true
            search(query)
        }

        private func send(_ object: [String: Any]) {
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.web?.evaluateJavaScript("window.sarahMapReceive(\(json));", completionHandler: nil)
            }
        }

        private func fail(_ message: String) {
            isLoading = false
            send(["kind": "error", "message": message])
        }

        private func search(_ query: String) {
            let folded = query.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                       locale: Locale(identifier: "fr_FR")).lowercased()
            var location = query
            // The POI category is not an address; geocode the named place.
            for separator in [" a cote de ", " pres de ", " autour de ", " a proximite de ",
                              " près de ", " à côté de ", " dans ", " vers ", " aux alentours de ",
                              " autour du ", " autour de la ", " à ", " a "] {
                let normalized = location.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                                   locale: Locale(identifier: "fr_FR")).lowercased()
                if let found = normalized.range(of: separator) {
                    let offset = normalized.distance(from: normalized.startIndex, to: found.upperBound)
                    if offset < location.count {
                        location = String(location.dropFirst(offset))
                        break
                    }
                }
            }
            if folded.contains("republique") && folded.contains("paris") {
                location = "Place de la République, Paris, France"
            } else if folded.contains("place de la republique") {
                location = "Place de la République, Paris, France"
            }
            // Avoid geocoding categories as names of towns.
            let prefix = location.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                          locale: Locale(identifier: "fr_FR")).lowercased()
            for word in ["restaurants ", "restaurant ", "cafes ", "cafe ", "hotels ", "hotel ",
                         "boutiques ", "boutique ", "recherche ", "cherche ", "montre ", "voir "] {
                if prefix.hasPrefix(word) { location = String(location.dropFirst(word.count)); break }
            }
            location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !location.isEmpty else { fail("Précise une adresse ou un lieu."); return }

            var url = URLComponents(string: "https://nominatim.openstreetmap.org/search")
            url?.queryItems = [
                URLQueryItem(name: "q", value: location),
                URLQueryItem(name: "format", value: "jsonv2"),
                URLQueryItem(name: "limit", value: "1"),
                URLQueryItem(name: "addressdetails", value: "1")
            ]
            guard let target = url?.url else { fail("Adresse non valide."); return }
            var request = URLRequest(url: target)
            request.timeoutInterval = 18
            request.setValue("SarahIA/1.0 (world map search; open-source project github.com/200012Yoel/SarahAI)", forHTTPHeaderField: "User-Agent")
            request.setValue("fr", forHTTPHeaderField: "Accept-Language")
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                guard let self else { return }
                guard error == nil, let data,
                      let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let first = results.first,
                      let latitude = Double(first["lat"] as? String ?? ""),
                      let longitude = Double(first["lon"] as? String ?? "") else {
                    self.fail("Adresse introuvable ou service cartographique indisponible.")
                    return
                }
                let label = (first["display_name"] as? String) ?? location
                self.send(["kind":"location","lat":latitude,"lon":longitude,"name":label])
                let category = folded.contains("restaurant") ? "restaurant"
                    : folded.contains("cafe") ? "cafe" : folded.contains("hotel") ? "hotel"
                    : folded.contains("boutique") || folded.contains("commerce") ? "shop" : ""
                if category.isEmpty { self.isLoading = false; return }
                self.searchPlaces(category: category, latitude: latitude, longitude: longitude)
            }.resume()
        }

        private func searchPlaces(category: String, latitude: Double, longitude: Double) {
            let around = "(around:850,\(latitude),\(longitude))"
            let selector = category == "hotel" ? "[\"tourism\"=\"hotel\"]"
                : category == "shop" ? "[\"shop\"]" : "[\"amenity\"=\"\(category)\"]"
            let query = "[out:json][timeout:20];(node\(selector)\(around);way\(selector)\(around);relation\(selector)\(around););out center 120;"
            guard let endpoint = URL(string: "https://overpass-api.de/api/interpreter") else {
                fail("Service de recherche indisponible."); return
            }
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.httpBody = Data(query.utf8)
            request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("SarahIA/1.0 (OSM places search)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 28
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                guard let self else { return }
                self.isLoading = false
                guard error == nil, let data,
                      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = payload["elements"] as? [[String: Any]] else {
                    self.send(["kind":"error","message":"Les commerces ne sont pas disponibles pour le moment. La carte reste utilisable."])
                    return
                }
                var places = [[String: Any]]()
                var identifiers = Set<String>()
                for entry in items {
                    let tags = entry["tags"] as? [String: Any] ?? [:]
                    let center = entry["center"] as? [String: Any] ?? [:]
                    let lat = (entry["lat"] as? Double) ?? (center["lat"] as? Double)
                    let lon = (entry["lon"] as? Double) ?? (center["lon"] as? Double)
                    guard let lat, let lon else { continue }
                    let id = "\(entry["type"] ?? "osm")/\(entry["id"] ?? 0)"
                    guard identifiers.insert(id).inserted else { continue }
                    let name = (tags["name:fr"] as? String) ?? (tags["name"] as? String) ?? "Lieu sans nom"
                    let street = [tags["addr:housenumber"], tags["addr:street"], tags["addr:city"]]
                        .compactMap { $0 as? String }.joined(separator: " ")
                    places.append(["lat":lat,"lon":lon,"name":name,"address":street,"id":id])
                }
                self.send(["kind":"places","places":places])
            }.resume()
        }
    }

    // Network-dependent WebGL map. A user can always retry search or pan it.
    // Vector 3D extrusions are data-driven, never fabricated satellite imagery.
    private static let html = #"""
<!doctype html><html lang="fr"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no"/>
<link href="https://unpkg.com/maplibre-gl@5.15.0/dist/maplibre-gl.css" rel="stylesheet"/>
<script src="https://unpkg.com/maplibre-gl@5.15.0/dist/maplibre-gl.js"></script>
<style>
*{box-sizing:border-box}html,body,#map{height:100%;width:100%;margin:0;background:#101a2b;color:white;font-family:-apple-system,system-ui,sans-serif}
#head{position:absolute;z-index:10;top:9px;left:9px;right:9px;display:flex;gap:7px}
#search{min-width:0;flex:1;border:1px solid #52647b;color:white;background:#10243ae9;padding:11px 12px;border-radius:13px;font-size:14px}
button{background:#2763da;border:0;color:white;border-radius:12px;padding:10px 12px;font-weight:700}
#status{position:absolute;z-index:10;bottom:36px;left:9px;right:9px;background:#0c192be6;border-radius:12px;padding:9px 12px;font-size:12px;line-height:1.4;max-height:78px;overflow-y:auto}
#options{position:absolute;z-index:10;right:9px;top:66px;display:grid;gap:7px}
#options button{border:1px solid #60718b;background:#132941ef}
.maplibregl-popup-content{background:#13243a;color:white;border-radius:13px;font:13px -apple-system,system-ui,sans-serif;box-shadow:0 8px 20px #0007}
.maplibregl-popup-tip{border-top-color:#13243a!important}
</style></head><body>
<div id="map"></div>
<div id="head"><input id="search" aria-label="Rechercher une adresse" placeholder="Adresse ou restaurants près d’un lieu"/><button id="go">Chercher</button></div>
<div id="options"><button id="globe" aria-label="Passer du globe au plan">🌍</button><button id="tilt" aria-label="Incliner la carte en 3D">3D</button><button id="reset" aria-label="Réorienter la vue">⌖</button></div>
<div id="status" role="status">Chargement de la carte…</div>
<script>
const INITIAL=__SARAH_INITIAL_QUERY__[0];
const status=document.getElementById('status'), box=document.getElementById('search');
box.value=INITIAL;
let map=null, markers=[], globe=false;
function say(message){status.textContent=message;}
function find(){const query=box.value.trim();if(!query)return; say('Recherche réelle en cours…');try{window.webkit.messageHandlers.sarahMap.postMessage({action:'search',query});}catch(e){say('Recherche indisponible. Vérifie la connexion Internet.');}}
document.getElementById('go').addEventListener('click',find);
box.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();box.blur();find();}});
window.sarahMapReceive=function(event){
 if(!map)return;
 if(event.kind==='error'){say(event.message);return;}
 if(event.kind==='location'){
   map.flyTo({center:[event.lon,event.lat],zoom:16.5,pitch:65,bearing:-22,speed:1.35});
   say('Lieu trouvé : '+event.name+'. Recherche de lieux à proximité…');
 }
 if(event.kind==='places'){
   markers.forEach(m=>m.remove());markers=[];
   for(const place of event.places){
      const element=document.createElement('div');
      element.style.cssText='width:24px;height:24px;border-radius:50%;border:2px solid white;background:#2069e8;box-shadow:0 2px 8px #0009;display:grid;place-items:center;color:white;cursor:pointer;font-size:13px';
      element.textContent='●';
      const container=document.createElement('div');
      const title=document.createElement('strong');title.textContent=place.name;container.appendChild(title);
      if(place.address){const line=document.createElement('p');line.textContent=place.address;container.appendChild(line);}
      const popup=new maplibregl.Popup({offset:20}).setDOMContent(container);
      markers.push(new maplibregl.Marker({element}).setLngLat([place.lon,place.lat]).setPopup(popup).addTo(map));
   }
   say(event.places.length+' lieux trouvés autour de cette adresse (données OpenStreetMap). Appuie sur un point bleu.');
 }
};
try{
 map=new maplibregl.Map({container:'map',style:'https://tiles.openfreemap.org/styles/liberty',
   center:[2.3637,48.8675],zoom:13.8,pitch:57,bearing:-16,antialias:true});
 map.addControl(new maplibregl.NavigationControl({showCompass:true}),'bottom-right');
 map.on('load',()=>{
   const layers=map.getStyle().layers||[];
   const before=layers.find(layer=>layer.type==='symbol'&&layer.layout&&layer.layout['text-field']);
   if(!map.getSource('sarah-buildings')){
     map.addSource('sarah-buildings',{url:'https://tiles.openfreemap.org/planet',type:'vector'});
   }
   if(!map.getLayer('sarah-3d-buildings'))map.addLayer({
     id:'sarah-3d-buildings',type:'fill-extrusion',source:'sarah-buildings',
     'source-layer':'building',minzoom:14,
     filter:['!=',['get','hide_3d'],true],
     paint:{
       'fill-extrusion-color':'#a9b9d2','fill-extrusion-opacity':0.8,
       'fill-extrusion-height':['coalesce',['to-number',['get','render_height']],['to-number',['get','height']],0],
       'fill-extrusion-base':['coalesce',['to-number',['get','render_min_height']],0]
     }
   },before&&before.id);
   if(INITIAL.trim())find();else say('Carte mondiale chargée. Recherche une adresse.');
 });
 map.on('error',e=>{if(status.textContent.includes('Chargement'))say('Données cartographiques indisponibles. Vérifie le réseau.');});
 document.getElementById('globe').onclick=()=>{
   globe=!globe; if(typeof map.setProjection==='function')map.setProjection({type:globe?'globe':'mercator'});
   say(globe?'Globe activé. Zoome pour explorer les bâtiments.':'Vue urbaine 3D activée.');
 };
 document.getElementById('tilt').onclick=()=>{map.easeTo({pitch:map.getPitch()>20?0:70,duration:650});};
 document.getElementById('reset').onclick=()=>{map.easeTo({bearing:0,pitch:60,duration:650});};
}catch(e){say('Impossible de charger la carte 3D. Vérifie Internet et le navigateur iOS.');}
</script></body></html>
"""#
}
