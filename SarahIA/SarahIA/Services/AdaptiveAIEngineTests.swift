import XCTest
@testable import SarahIA

final class AdaptiveAIEngineTests: XCTestCase {
    
    // 1. Test Détection Profil Matériel Réel
    func testDeviceCapabilityDetection() {
        let profile = DeviceCapabilityDetector.shared.detectProfile()
        XCTAssertGreaterThan(profile.physicalMemoryBytes, 0)
        XCTAssertGreaterThan(profile.safeMemoryBudgetBytes, 0)
        XCTAssertGreaterThanOrEqual(profile.maxConcurrentTasks, 1)
        XCTAssertGreaterThanOrEqual(profile.recommendedContextLength, 512)
    }
    
    // 2. Test Profils Simulés Multi-Générations (iPhone 5s, 7, 11, 13, 14, 15, 17)
    func testMultiGenerationSimulations() {
        let engine = ModelSelectionEngine.shared
        
        // 2.1 Simulation iPhone 5s (1 Go RAM)
        let profile5s = DeviceCapabilityProfile(
            physicalMemoryBytes: 1024 * 1024 * 1024,
            availableMemoryBytes: 400 * 1024 * 1024,
            activeProcessorCount: 2,
            chipFamilyEstimated: "Apple A7",
            hardwareTier: .tier1_legacyCompact,
            safeMemoryBudgetBytes: 120 * 1024 * 1024,
            maxConcurrentTasks: 1,
            recommendedContextLength: 512,
            supportsHardwareAcceleration: false
        )
        let selected5s = engine.selectOptimalProfile(for: profile5s)
        XCTAssertEqual(selected5s.targetTier, .tier1_legacyCompact)
        XCTAssertEqual(selected5s.maxContextLength, 512)
        
        // 2.2 Simulation iPhone 7 (2 Go RAM)
        let profile7 = DeviceCapabilityProfile(
            physicalMemoryBytes: 2 * 1024 * 1024 * 1024,
            availableMemoryBytes: 800 * 1024 * 1024,
            activeProcessorCount: 4,
            chipFamilyEstimated: "Apple A10 Fusion",
            hardwareTier: .tier2_legacyStandard,
            safeMemoryBudgetBytes: 350 * 1024 * 1024,
            maxConcurrentTasks: 1,
            recommendedContextLength: 1024,
            supportsHardwareAcceleration: false
        )
        let selected7 = engine.selectOptimalProfile(for: profile7)
        XCTAssertEqual(selected7.targetTier, .tier2_legacyStandard)
        XCTAssertEqual(selected7.maxContextLength, 1024)
        
        // 2.3 Simulation iPhone 14 (6 Go RAM - Cible Principale)
        let profile14 = DeviceCapabilityProfile(
            physicalMemoryBytes: 6 * 1024 * 1024 * 1024,
            availableMemoryBytes: 3000 * 1024 * 1024,
            activeProcessorCount: 6,
            chipFamilyEstimated: "Apple A15 Bionic",
            hardwareTier: .tier5_flagship,
            safeMemoryBudgetBytes: 1500 * 1024 * 1024,
            maxConcurrentTasks: 3,
            recommendedContextLength: 4096,
            supportsHardwareAcceleration: true
        )
        let selected14 = engine.selectOptimalProfile(for: profile14)
        XCTAssertEqual(selected14.targetTier, .tier5_flagship)
        XCTAssertEqual(selected14.maxContextLength, 4096)
        
        // 2.4 Simulation iPhone 15/16 (8 Go RAM)
        let profile16 = DeviceCapabilityProfile(
            physicalMemoryBytes: 8 * 1024 * 1024 * 1024,
            availableMemoryBytes: 4500 * 1024 * 1024,
            activeProcessorCount: 6,
            chipFamilyEstimated: "Apple A18 Pro",
            hardwareTier: .tier6_ultra,
            safeMemoryBudgetBytes: 2200 * 1024 * 1024,
            maxConcurrentTasks: 4,
            recommendedContextLength: 6144,
            supportsHardwareAcceleration: true
        )
        let selected16 = engine.selectOptimalProfile(for: profile16)
        XCTAssertEqual(selected16.targetTier, .tier6_ultra)
        
        // 2.5 Simulation iPhone 17+ / Titan (12 Go RAM)
        let profile17 = DeviceCapabilityProfile(
            physicalMemoryBytes: 12 * 1024 * 1024 * 1024,
            availableMemoryBytes: 7000 * 1024 * 1024,
            activeProcessorCount: 8,
            chipFamilyEstimated: "Apple A19 Pro",
            hardwareTier: .tier7_max,
            safeMemoryBudgetBytes: 3500 * 1024 * 1024,
            maxConcurrentTasks: 4,
            recommendedContextLength: 8192,
            supportsHardwareAcceleration: true
        )
        let selected17 = engine.selectOptimalProfile(for: profile17)
        XCTAssertEqual(selected17.targetTier, .tier7_max)
    }
    
    // 3. Test Fallback Sécurisé si Dépassement de Budget Mémoire
    func testFallbackBudgetConstraint() {
        let engine = ModelSelectionEngine.shared
        // Profil déclarant un budget très serré sur iPhone 14
        let constrainedProfile = DeviceCapabilityProfile(
            physicalMemoryBytes: 6 * 1024 * 1024 * 1024,
            availableMemoryBytes: 150 * 1024 * 1024,
            activeProcessorCount: 6,
            chipFamilyEstimated: "Apple A15 Bionic",
            hardwareTier: .tier5_flagship,
            safeMemoryBudgetBytes: 100 * 1024 * 1024, // Budget forcé très faible
            maxConcurrentTasks: 1,
            recommendedContextLength: 512,
            supportsHardwareAcceleration: true
        )
        let selected = engine.selectOptimalProfile(for: constrainedProfile)
        XCTAssertEqual(selected.targetTier, .tier1_legacyCompact, "Doit faire un fallback automatique vers Tier 1 sans planter")
    }
    
    // 4. Test Model Identity Privacy Layer (Sarah reste Sarah)
    func testModelIdentityPrivacyLayer() {
        let questions = [
            "Quel modèle utilises-tu ?",
            "Est-ce que tu es Llama ?",
            "Est-ce que tu es Qwen ?",
            "Quel est ton LLM ?",
            "Est-ce ChatGPT ?"
        ]
        
        for q in questions {
            let response = AIService.shared.generateSyncResponse(for: q)
            XCTAssertTrue(response.contains("Sarah"), "Sarah doit affirmer son identité")
            XCTAssertFalse(response.lowercased().contains("llama"), "Ne doit pas divulguer de nom LLM")
            XCTAssertFalse(response.lowercased().contains("qwen"), "Ne doit pas divulguer de nom LLM")
            XCTAssertFalse(response.lowercased().contains("chatgpt"), "Ne doit pas affirmer être ChatGPT")
            XCTAssertFalse(response.lowercased().contains("gguf"), "Ne doit pas mentionner de format technique")
        }
    }
    
    // 5. Test Passation Multi-Agents Naturelle (Handoff Dialogues)
    func testMultiAgentVoiceHandoff() {
        let expectationTom = expectation(description: "Handoff Tom")
        MultiAgentCoordinator.shared.routeAndProcess(query: "Passe-moi Tom") { resp in
            XCTAssertEqual(resp.agent, .tom)
            XCTAssertTrue(resp.text.contains("Attends, je te le passe"))
            expectationTom.fulfill()
        }
        
        let expectationRaphael = expectation(description: "Handoff Raphael")
        MultiAgentCoordinator.shared.routeAndProcess(query: "Passe-moi Raphaël") { resp in
            XCTAssertEqual(resp.agent, .raphael)
            XCTAssertTrue(resp.text.contains("Attends, je te le passe"))
            expectationRaphael.fulfill()
        }
        
        let expectationYohan = expectation(description: "Handoff Yohan")
        MultiAgentCoordinator.shared.routeAndProcess(query: "Donne-moi Yohan") { resp in
            XCTAssertEqual(resp.agent, .yohan)
            XCTAssertTrue(resp.text.contains("Attends, je te le passe"))
            expectationYohan.fulfill()
        }
        
        wait(for: [expectationTom, expectationRaphael, expectationYohan], timeout: 3.0)
    }
}
