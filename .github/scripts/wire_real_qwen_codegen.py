from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_function(text: str, signature_token: str, replacement: str) -> str:
    idx = text.find(signature_token)
    if idx < 0:
        raise SystemExit(f"Missing function: {signature_token}")
    start = text.rfind("\n", 0, idx) + 1
    scan = start
    while scan > 0:
        end_prev = scan - 1
        prev = text.rfind("\n", 0, end_prev) + 1
        line = text[prev:end_prev].strip()
        if line.startswith("///") or line.startswith("//") or not line:
            start = prev
            scan = prev
        else:
            break
    brace = text.find("{", idx)
    if brace < 0:
        raise SystemExit("Opening brace missing")
    depth = 0
    in_string = False
    triple = False
    escape = False
    i = brace
    end = None
    while i < len(text):
        if text.startswith('"""', i):
            triple = not triple
            i += 3
            continue
        ch = text[i]
        if triple:
            i += 1
            continue
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    if end is None:
        raise SystemExit("Closing brace missing")
    while end < len(text) and text[end] in " \t\n":
        end += 1
    return text[:start] + replacement.rstrip() + "\n\n" + text[end:]


# -----------------------------------------------------------------------------
# AIService: real local Qwen3 GGUF inference via llama.cpp.
# -----------------------------------------------------------------------------
ai_path = ROOT / "SarahIA/SarahIA/Services/AIService.swift"
ai = ai_path.read_text(encoding="utf-8")

if "#if canImport(llama)" not in ai:
    ai = ai.replace(
        "import UIKit\n",
        "import UIKit\n#if canImport(llama)\nimport llama\n#endif\n",
        1,
    )

runtime_marker = "public final class QwenLocalCodeRuntime"
if runtime_marker not in ai:
    insertion_point = ai.find("public final class AIService")
    if insertion_point < 0:
        raise SystemExit("AIService class marker missing")

    runtime = r'''
/// Runtime de génération de code réellement branché sur les poids Qwen3 GGUF.
/// Aucune page HTML déterministe n'est construite ici : chaque token provient
/// de llama.cpp exécutant le modèle téléchargé dans Application Support.
public final class QwenLocalCodeRuntime {
    public static let shared = QwenLocalCodeRuntime()
    private let queue = DispatchQueue(label: "com.sarahia.qwen.codegen", qos: .userInitiated)
    private var backendInitialized = false

    private init() {}

    public var isRuntimeLinked: Bool {
        #if canImport(llama)
        return true
        #else
        return false
        #endif
    }

    public func generate(
        modelURL: URL,
        system: String,
        user: String,
        maxTokens: Int = 3072,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else { return }
            #if canImport(llama)
            do {
                let value = try self.infer(
                    modelURL: modelURL,
                    system: system,
                    user: user,
                    maxTokens: maxTokens
                )
                DispatchQueue.main.async { completion(.success(value)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
            #else
            let error = NSError(
                domain: "SarahQwenRuntime",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Le runtime llama.cpp n'est pas lié à cette installation de SarahIA."]
            )
            DispatchQueue.main.async { completion(.failure(error)) }
            #endif
        }
    }

    #if canImport(llama)
    private func infer(
        modelURL: URL,
        system: String,
        user: String,
        maxTokens: Int
    ) throws -> String {
        if !backendInitialized {
            llama_backend_init()
            backendInitialized = true
        }

        let modelParams = llama_model_default_params()
        guard let model = llama_model_load_from_file(modelURL.path.cString(using: .utf8), modelParams) else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Impossible de charger le modèle Qwen3 GGUF."]
            )
        }
        defer { llama_model_free(model) }

        guard let vocab = llama_model_get_vocab(model) else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Tokenizer Qwen3 indisponible."]
            )
        }

        // Qwen3 utilise nativement le format ChatML. Les tokens spéciaux sont
        // réellement passés au tokenizer llama.cpp, contrairement à l'ancien routeur.
        let prompt = """
        <|im_start|>system
        \(system)
        <|im_end|>
        <|im_start|>user
        \(user)
        <|im_end|>
        <|im_start|>assistant
        """

        var tokenCapacity = max(256, prompt.utf8.count + 64)
        var tokens = [llama_token](repeating: 0, count: tokenCapacity)

        func tokenize(into buffer: inout [llama_token]) -> Int32 {
            prompt.withCString { cPrompt in
                buffer.withUnsafeMutableBufferPointer { tokenBuffer in
                    llama_tokenize(
                        vocab,
                        cPrompt,
                        Int32(prompt.utf8.count),
                        tokenBuffer.baseAddress,
                        Int32(tokenBuffer.count),
                        true,
                        true
                    )
                }
            }
        }

        var tokenCount = tokenize(into: &tokens)
        if tokenCount < 0 {
            tokenCapacity = Int(-tokenCount)
            tokens = [llama_token](repeating: 0, count: tokenCapacity)
            tokenCount = tokenize(into: &tokens)
        }
        guard tokenCount > 0 else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Le prompt n'a pas pu être tokenisé par Qwen3."]
            )
        }
        tokens = Array(tokens.prefix(Int(tokenCount)))

        let outputBudget = max(256, min(maxTokens, 4096))
        let maxContext = 8192
        let maxPromptTokens = max(512, maxContext - outputBudget - 64)
        if tokens.count > maxPromptTokens {
            tokens = Array(tokens.prefix(maxPromptTokens))
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(maxContext)
        contextParams.n_batch = 512
        let cpuCount = max(2, min(6, ProcessInfo.processInfo.activeProcessorCount))
        contextParams.n_threads = Int32(cpuCount)
        contextParams.n_threads_batch = Int32(cpuCount)

        guard let context = llama_init_from_model(model, contextParams) else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1005,
                userInfo: [NSLocalizedDescriptionKey: "Impossible d'initialiser le contexte Qwen3."]
            )
        }
        defer { llama_free(context) }

        let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
        guard let sampler else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1006,
                userInfo: [NSLocalizedDescriptionKey: "Impossible d'initialiser l'échantillonneur Qwen3."]
            )
        }
        defer { llama_sampler_free(sampler) }
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.90, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.20))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(20261001))

        // Le prompt est évalué par blocs pour limiter la mémoire temporaire sur iPhone.
        var consumed = 0
        while consumed < tokens.count {
            let chunkCount = min(512, tokens.count - consumed)
            var batch = llama_batch_init(Int32(chunkCount), 0, 1)
            defer { llama_batch_free(batch) }
            batch.n_tokens = Int32(chunkCount)

            for localIndex in 0..<chunkCount {
                let globalIndex = consumed + localIndex
                batch.token[localIndex] = tokens[globalIndex]
                batch.pos[localIndex] = Int32(globalIndex)
                batch.n_seq_id[localIndex] = 1
                if let seq = batch.seq_id[localIndex] { seq[0] = 0 }
                batch.logits[localIndex] = (globalIndex == tokens.count - 1) ? 1 : 0
            }

            guard llama_decode(context, batch) == 0 else {
                throw NSError(
                    domain: "SarahQwenRuntime",
                    code: 1007,
                    userInfo: [NSLocalizedDescriptionKey: "Qwen3 n'a pas pu évaluer le prompt."]
                )
            }
            consumed += chunkCount
        }

        func piece(for token: llama_token) -> String {
            var bytes = [CChar](repeating: 0, count: 16)
            var written = llama_token_to_piece(vocab, token, &bytes, Int32(bytes.count), 0, true)
            if written < 0 {
                bytes = [CChar](repeating: 0, count: Int(-written))
                written = llama_token_to_piece(vocab, token, &bytes, Int32(bytes.count), 0, true)
            }
            guard written > 0 else { return "" }
            let data = Data(bytes.prefix(Int(written)).map { UInt8(bitPattern: $0) })
            return String(data: data, encoding: .utf8) ?? ""
        }

        var result = ""
        var position = tokens.count

        for _ in 0..<outputBudget {
            let token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }

            let fragment = piece(for: token)
            result += fragment
            if result.contains("<|im_end|>") { break }

            var batch = llama_batch_init(1, 0, 1)
            defer { llama_batch_free(batch) }
            batch.n_tokens = 1
            batch.token[0] = token
            batch.pos[0] = Int32(position)
            batch.n_seq_id[0] = 1
            if let seq = batch.seq_id[0] { seq[0] = 0 }
            batch.logits[0] = 1

            guard llama_decode(context, batch) == 0 else { break }
            position += 1
            if position >= maxContext - 1 { break }
        }

        let clean = result
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !clean.isEmpty else {
            throw NSError(
                domain: "SarahQwenRuntime",
                code: 1008,
                userInfo: [NSLocalizedDescriptionKey: "Qwen3 n'a produit aucun code."]
            )
        }
        return clean
    }
    #endif
}

'''
    ai = ai[:insertion_point] + runtime + ai[insertion_point:]

replacement = r'''    /// Génération de code issue exclusivement d'un vrai modèle génératif.
    /// Aucun template HTML et aucun moteur déterministe ne sont autorisés ici.
    public func generateLocalCodeDocument(
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            completion(.failure(NSError(
                domain: "SarahLocalCodeGeneration",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Prompt de code vide"]
            )))
            return
        }

        guard ModelSelectionEngine.shared.isLocalGGUFAllowed() else {
            completion(.failure(NSError(
                domain: "SarahLocalCodeGeneration",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Cet iPhone ne dispose pas d'un budget mémoire suffisant pour Qwen3 GGUF local."]
            )))
            return
        }

        guard BackgroundModelDownloader.isModelDownloaded,
              let modelURL = BackgroundModelDownloader.localModelURL else {
            BackgroundModelDownloader.shared.startQwenModelDownload()
            completion(.failure(NSError(
                domain: "SarahLocalCodeGeneration",
                code: 425,
                userInfo: [NSLocalizedDescriptionKey: "Le vrai modèle Qwen3 est en préparation. Sarah ne générera aucun faux site pendant son téléchargement."]
            )))
            return
        }

        let system = """
        Tu es Raphaël, développeur web senior. Génère réellement le code demandé avec le modèle Qwen3 exécuté localement. Retourne uniquement un document HTML5 complet et autonome avec CSS et JavaScript intégrés. Aucun template pré-écrit, aucun lorem ipsum, aucun faux bouton, aucun asset distant et aucun texte hors du HTML.
        """

        QwenLocalCodeRuntime.shared.generate(
            modelURL: modelURL,
            system: system,
            user: clean,
            maxTokens: 3072,
            completion: completion
        )
    }
'''
ai = replace_function(ai, "public func generateLocalCodeDocument(", replacement)
ai_path.write_text(ai, encoding="utf-8")


# -----------------------------------------------------------------------------
# Device build: compile and link official llama.cpp XCFramework.
# -----------------------------------------------------------------------------
workflow_path = ROOT / ".github/workflows/ios-build.yml"
workflow = workflow_path.read_text(encoding="utf-8")

if "Build llama.cpp v0.4.1 XCFramework" not in workflow:
    marker = "      - name: Build whisper.cpp v1.9.4 XCFramework\n"
    if marker not in workflow:
        raise SystemExit("Whisper build step marker missing")
    llama_step = '''      - name: Build llama.cpp v0.4.1 XCFramework
        run: |
          set -euo pipefail
          LLAMA_ROOT="$RUNNER_TEMP/llama.cpp"
          rm -rf "$LLAMA_ROOT"
          git clone --depth 1 --branch v0.4.1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_ROOT"
          cd "$LLAMA_ROOT"
          ./build-xcframework.sh ios-device
          test -d build-apple/llama.xcframework
          find build-apple/llama.xcframework -maxdepth 3 -type d -name 'llama.framework' -print

'''
    workflow = workflow.replace(marker, llama_step + marker, 1)

workflow = workflow.replace(
    "          grep -q 'qualitySystemPrompt' SarahIA/SarahIA/Services/VAICodeEngine.swift\n",
    "          grep -q 'qualitySystemPrompt' SarahIA/SarahIA/Services/VAICodeEngine.swift\n"
    "          grep -q 'QwenLocalCodeRuntime.shared.generate' SarahIA/SarahIA/Services/AIService.swift\n"
    "          grep -q '^import llama' SarahIA/SarahIA/Services/AIService.swift || grep -q '#if canImport(llama)' SarahIA/SarahIA/Services/AIService.swift\n"
    "          ! grep -A80 'public func generateLocalCodeDocument' SarahIA/SarahIA/Services/AIService.swift | grep -q 'LocalNeuralIntelligenceEngine.shared.generateLocalResponse'\n",
    1,
)

old_framework = '''          WHISPER_FRAMEWORK=$(find "$RUNNER_TEMP/whisper.cpp/build-apple/whisper.xcframework" -path '*/ios-arm64/whisper.framework' -type d -print -quit)
          test -n "$WHISPER_FRAMEWORK"
          test "$(basename "$(dirname "$WHISPER_FRAMEWORK")")" = "ios-arm64"
          WHISPER_FRAMEWORK_DIR=$(dirname "$WHISPER_FRAMEWORK")
          echo "Using iPhone Whisper framework: $WHISPER_FRAMEWORK"
'''
new_framework = old_framework + '''          LLAMA_FRAMEWORK=$(find "$RUNNER_TEMP/llama.cpp/build-apple/llama.xcframework" -path '*/ios-arm64/llama.framework' -type d -print -quit)
          test -n "$LLAMA_FRAMEWORK"
          LLAMA_FRAMEWORK_DIR=$(dirname "$LLAMA_FRAMEWORK")
          echo "Using iPhone llama.cpp framework: $LLAMA_FRAMEWORK"
'''
if "LLAMA_FRAMEWORK_DIR=$(dirname" not in workflow:
    if old_framework not in workflow:
        raise SystemExit("Device framework marker missing")
    workflow = workflow.replace(old_framework, new_framework, 1)

workflow = workflow.replace(
    '            FRAMEWORK_SEARCH_PATHS="$WHISPER_FRAMEWORK_DIR" \\\n',
    '            FRAMEWORK_SEARCH_PATHS="$WHISPER_FRAMEWORK_DIR $LLAMA_FRAMEWORK_DIR" \\\n',
    1,
)
workflow = workflow.replace(
    "            OTHER_LDFLAGS='$(inherited) -framework whisper -framework Accelerate -framework Metal -framework CoreML' \\\n",
    "            OTHER_LDFLAGS='$(inherited) -framework whisper -framework llama -framework Accelerate -framework Metal -framework MetalKit -framework CoreML' \\\n",
    1,
)

bundle_marker = '''          WHISPER_FRAMEWORK=$(find "$RUNNER_TEMP/whisper.cpp/build-apple/whisper.xcframework" -path '*/ios-arm64/whisper.framework' -type d -print -quit)
          test -n "$WHISPER_FRAMEWORK"
          if file "$WHISPER_FRAMEWORK/whisper" | grep -q 'dynamically linked shared library'; then
            mkdir -p "$APP_PATH/Frameworks"
            cp -R "$WHISPER_FRAMEWORK" "$APP_PATH/Frameworks/"
          fi
'''
if "LLAMA_FRAMEWORK=$(find \"$RUNNER_TEMP/llama.cpp/build-apple/llama.xcframework\"" not in workflow.split("- name: Bundle Whisper model and licenses", 1)[-1]:
    if bundle_marker not in workflow:
        raise SystemExit("Bundle framework marker missing")
    llama_bundle = bundle_marker + '''
          LLAMA_FRAMEWORK=$(find "$RUNNER_TEMP/llama.cpp/build-apple/llama.xcframework" -path '*/ios-arm64/llama.framework' -type d -print -quit)
          test -n "$LLAMA_FRAMEWORK"
          if file "$LLAMA_FRAMEWORK/llama" | grep -q 'dynamically linked shared library'; then
            mkdir -p "$APP_PATH/Frameworks"
            cp -R "$LLAMA_FRAMEWORK" "$APP_PATH/Frameworks/"
          fi
'''
    workflow = workflow.replace(bundle_marker, llama_bundle, 1)

workflow = workflow.replace(
    "Canonical OpenAI Whisper speech recognition with continuous voice barge-in and iOS acoustic echo cancellation via whisper.cpp.",
    "Canonical OpenAI Whisper voice plus real local Qwen3 GGUF website/code generation through official llama.cpp. No deterministic HTML fallback.",
)
workflow_path.write_text(workflow, encoding="utf-8")

print("Real local Qwen3 GGUF code generation wired through llama.cpp")
