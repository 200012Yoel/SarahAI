import SwiftUI

/// Vue feuille de gestion visuelle de la mémoire permanente ("AI Brain Vault") de Sarah.
public struct MemoryVaultView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ChatViewModel
    
    @State private var searchText: String = ""
    @State private var isAddingNewMemory: Bool = false
    @State private var newTrigger: String = ""
    @State private var newResponse: String = ""
    @State private var showingDeleteAllAlert: Bool = false
    
    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }
    
    private var filteredMemories: [(trigger: String, response: String)] {
        let memories = viewModel.learnedMemories
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return memories.map { ($0.key, $0.value) }.sorted { $0.trigger < $1.trigger }
        } else {
            let lower = searchText.lowercased()
            return memories
                .filter { $0.key.lowercased().contains(lower) || $0.value.lowercased().contains(lower) }
                .map { ($0.key, $0.value) }
                .sorted { $0.trigger < $1.trigger }
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // En-tête statistique
                    headerStatsCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Barre de recherche
                    searchBar
                        .padding(.horizontal, 16)
                    
                    // Liste des souvenirs
                    if filteredMemories.isEmpty {
                        emptyStateView
                    } else {
                        memoryListView
                    }
                }
            }
            .navigationTitle("🧠 Mémoire de Sarah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Fermer")
                            .foregroundColor(.cyan)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticService.shared.buttonTap()
                        isAddingNewMemory = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $isAddingNewMemory) {
                addMemorySheet
            }
            .alert(isPresented: $showingDeleteAllAlert) {
                Alert(
                    title: Text("Réinitialiser la mémoire ?"),
                    message: Text("Tous les mots appris seront définitivement effacés."),
                    primaryButton: .destructive(Text("Tout effacer")) {
                        viewModel.clearAllLearnedMemories()
                        HapticService.shared.memoryDeleted()
                    },
                    secondaryButton: .cancel(Text("Annuler"))
                )
            }
        }
    }
    
    // MARK: - Components
    
    private var headerStatsCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cerveau Permanent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
                Text("\(viewModel.learnedMemories.count) associations apprises")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            if !viewModel.learnedMemories.isEmpty {
                Button(action: {
                    showingDeleteAllAlert = true
                }) {
                    Text("Effacer tout")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Rechercher un mot ou une réponse...", text: $searchText)
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(10)
    }
    
    private var memoryListView: some View {
        List {
            ForEach(filteredMemories, id: \.trigger) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quand vous dites :")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan)
                        Spacer()
                        
                        Button(action: {
                            HapticService.shared.buttonTap()
                            viewModel.speakLearnedResponse(text: item.response)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12))
                                Text("Écouter")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.25))
                            .cornerRadius(6)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    Text("« \(item.trigger) »")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    Text("Sarah répond :")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("« \(item.response) »")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(red: 0.85, green: 0.90, blue: 1.0))
                }
                .padding(12)
                .background(Color(red: 0.10, green: 0.10, blue: 0.14))
                .cornerRadius(12)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteLearnedMemory(trigger: item.trigger)
                        HapticService.shared.memoryDeleted()
                    } label: {
                        Label("Oublier", systemName: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 54))
                .foregroundColor(.cyan.opacity(0.6))
            
            Text("Aucune mémoire enregistrée")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Dites à Sarah « Apprends papa » ou appuyez sur le bouton « + » ci-dessus pour lui enseigner vos réponses personnalisées !")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                isAddingNewMemory = true
            }) {
                Text("Enseigner une réponse")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.cyan)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var addMemorySheet: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MOT OU PHRASE DÉCLENCHEUR")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        
                        TextField("Ex: Papa", text: $newTrigger)
                            .padding(12)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RÉPONSE DE SARAH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        
                        TextField("Ex: Il est pas là", text: $newResponse)
                            .padding(12)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        let trig = newTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resp = newResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trig.isEmpty, !resp.isEmpty else { return }
                        
                        viewModel.addLearnedMemory(trigger: trig, response: resp)
                        HapticService.shared.memoryLearned()
                        newTrigger = ""
                        newResponse = ""
                        isAddingNewMemory = false
                    }) {
                        Text("Mémoriser dans Sarah AI")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background((newTrigger.isEmpty || newResponse.isEmpty) ? Color.gray : Color.cyan)
                            .cornerRadius(12)
                    }
                    .disabled(newTrigger.isEmpty || newResponse.isEmpty)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Nouvelle Connaissance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        isAddingNewMemory = false
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}
