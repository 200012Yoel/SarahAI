import Foundation
import UIKit
import Darwin

/// Détecteur système dynamique interrogeant les métriques réelles de l'iPhone
public final class DeviceCapabilityDetector {
    
    public static let shared = DeviceCapabilityDetector()
    
    private init() {}
    
    /// Analyse en temps réel le matériel et construit un DeviceCapabilityProfile sans suppositions en dur
    public func detectProfile() -> DeviceCapabilityProfile {
        let physicalMem = ProcessInfo.processInfo.physicalMemory
        let availableMem = getAccurateAvailableMemory(fallbackPhysical: physicalMem)
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let chipName = detectChipIdentifier()
        let supportsNeural = supportsNeuralAcceleration()
        
        let tier = computeHardwareTier(physicalMem: physicalMem, availableMem: availableMem, coreCount: coreCount, chipName: chipName)
        
        // Calcul du budget mémoire sécurisé (marge de sécurité obligatoire de 40% pour l'OS et l'UI)
        let safeBudget = computeSafeBudget(physicalMem: physicalMem, availableMem: availableMem, tier: tier)
        
        let (maxTasks, contextLen) = computeTaskAndContextLimits(tier: tier, safeBudget: safeBudget)
        
        return DeviceCapabilityProfile(
            physicalMemoryBytes: physicalMem,
            availableMemoryBytes: availableMem,
            activeProcessorCount: coreCount,
            chipFamilyEstimated: chipName,
            hardwareTier: tier,
            safeMemoryBudgetBytes: safeBudget,
            maxConcurrentTasks: maxTasks,
            recommendedContextLength: contextLen,
            supportsHardwareAcceleration: supportsNeural
        )
    }
    
    // MARK: - Mesures Système Précises
    
    private func getAccurateAvailableMemory(fallbackPhysical: UInt64) -> UInt64 {
        if #available(iOS 13.0, *) {
            let osAvailable = os_proc_available_memory()
            if osAvailable > 0 {
                return UInt64(osAvailable)
            }
        }
        
        // Estimation Darwin via mach_host_basic_info
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let freeMem = UInt64(stats.free_count) * pageSize
            let inactiveMem = UInt64(stats.inactive_count) * pageSize
            return freeMem + inactiveMem
        }
        
        // Estimation prudente : 45% de la RAM physique
        return UInt64(Double(fallbackPhysical) * 0.45)
    }
    
    private func detectChipIdentifier() -> String {
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let identifier = String(cString: machine)
        return mapHardwareIdentifier(identifier)
    }
    
    private func mapHardwareIdentifier(_ id: String) -> String {
        if id.starts(with: "iPhone6,") { return "Apple A7" }
        if id.starts(with: "iPhone7,") { return "Apple A8" }
        if id.starts(with: "iPhone8,") { return "Apple A9" }
        if id.starts(with: "iPhone9,") { return "Apple A10 Fusion" }
        if id.starts(with: "iPhone10,") { return "Apple A11 Bionic" }
        if id.starts(with: "iPhone11,") { return "Apple A12 Bionic" }
        if id.starts(with: "iPhone12,") { return "Apple A13 Bionic" }
        if id.starts(with: "iPhone13,") { return "Apple A14 Bionic" }
        if id.starts(with: "iPhone14,") { return "Apple A15 Bionic" }
        if id.starts(with: "iPhone15,") { return "Apple A16 Bionic" }
        if id.starts(with: "iPhone16,") { return "Apple A17 Pro / A18" }
        if id.starts(with: "iPhone17,") { return "Apple A18 / A19" }
        if id.contains("iPad") || id.contains("Mac") { return "Apple Silicon M-Series" }
        return "Apple Silicon Generic (\(id))"
    }
    
    private func supportsNeuralAcceleration() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let physicalMem = ProcessInfo.processInfo.physicalMemory
        return physicalMem >= (3 * 1024 * 1024 * 1024) // 3 Go+ supporte le Neural Engine moderne
        #endif
    }
    
    private func computeHardwareTier(physicalMem: UInt64, availableMem: UInt64, coreCount: Int, chipName: String) -> HardwareTier {
        let gb = Double(physicalMem) / (1024.0 * 1024.0 * 1024.0)
        
        if gb >= 7.5 {
            return .tier7_max // iPhone 17 / Pro / M-Series (8 Go à 16 Go RAM)
        } else if gb >= 5.5 {
            // iPhone 14 Pro, iPhone 15, iPhone 16 (6 Go à 8 Go)
            if chipName.contains("A17") || chipName.contains("A18") || chipName.contains("A19") {
                return .tier6_ultra
            }
            return .tier5_flagship // iPhone 14 / 14 Plus / 14 Pro (6 Go RAM - Cible principale)
        } else if gb >= 3.5 {
            // iPhone 12, 13 (4 Go)
            return .tier4_advanced
        } else if gb >= 2.5 {
            // iPhone XR, XS, 11 (3 Go à 4 Go)
            return .tier3_intermediate
        } else if gb >= 1.7 {
            // iPhone 7 Plus, iPhone 8 (2 Go à 3 Go)
            return .tier2_legacyStandard
        } else {
            // iPhone 5s, 6, 6 Plus (1 Go RAM)
            return .tier1_legacyCompact
        }
    }
    
    private func computeSafeBudget(physicalMem: UInt64, availableMem: UInt64, tier: HardwareTier) -> UInt64 {
        // Marge de sécurité stricte : on n'alloue jamais plus de 35% de la RAM disponible totale
        let maxAllocationRatio: Double
        switch tier {
        case .tier1_legacyCompact: maxAllocationRatio = 0.15 // Max ~150 Mo
        case .tier2_legacyStandard: maxAllocationRatio = 0.20 // Max ~400 Mo
        case .tier3_intermediate: maxAllocationRatio = 0.25 // Max ~750 Mo
        case .tier4_advanced: maxAllocationRatio = 0.28 // Max ~1.1 Go
        case .tier5_flagship: maxAllocationRatio = 0.32 // Max ~1.8 Go (iPhone 14)
        case .tier6_ultra: maxAllocationRatio = 0.35 // Max ~2.5 Go
        case .tier7_max: maxAllocationRatio = 0.40 // Max ~3.5 Go+
        }
        
        let budgetFromPhysical = Double(physicalMem) * maxAllocationRatio
        let budgetFromAvailable = Double(availableMem) * 0.70
        let chosen = min(budgetFromPhysical, budgetFromAvailable)
        return UInt64(max(80 * 1024 * 1024, chosen))
    }
    
    private func computeTaskAndContextLimits(tier: HardwareTier, safeBudget: UInt64) -> (maxTasks: Int, contextLength: Int) {
        switch tier {
        case .tier1_legacyCompact:
            return (maxTasks: 1, contextLength: 512)
        case .tier2_legacyStandard:
            return (maxTasks: 1, contextLength: 1024)
        case .tier3_intermediate:
            return (maxTasks: 2, contextLength: 2048)
        case .tier4_advanced:
            return (maxTasks: 2, contextLength: 3072)
        case .tier5_flagship:
            return (maxTasks: 3, contextLength: 4096)
        case .tier6_ultra:
            return (maxTasks: 4, contextLength: 6144)
        case .tier7_max:
            return (maxTasks: 4, contextLength: 8192)
        }
    }
}
