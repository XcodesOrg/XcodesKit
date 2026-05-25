//
//  Architecture.swift
//  XcodesKit
//
//  Created by Matt Kiazyk on 2025-08-23.
//

import Foundation

/// A CPU architecture supported by an Xcode or simulator runtime artifact.
public enum Architecture: String, Codable, Equatable, Hashable, Identifiable, CaseIterable, Sendable {
    public var id: Self { self }
    
    /// The Arm64 architecture (Apple Silicon)
    case arm64 = "arm64"
    /// The X86\_64 architecture (64-bit Intel)
    case x86_64 = "x86_64"
    
    /// A localized human-readable architecture name.
    public var displayString: String {
        switch self {
        case .arm64:
            return localizeString("Apple Silicon")
        case .x86_64:
            return localizeString("Intel")
        }
    }
    
    /// The SF Symbol name used to represent this architecture.
    public var iconName: String {
        switch self {
            case .arm64:
                return "m4.button.horizontal"
            case .x86_64:
                return "cpu.fill"
        }
    }
}

/// A higher-level architecture filter such as universal or Apple Silicon-only.
public enum ArchitectureVariant: String, Codable, Equatable, Hashable, Identifiable, CaseIterable, Sendable {
    public var id: Self { self }
    
    /// Artifacts that support both Apple Silicon and Intel.
    case universal
    /// Artifacts that support only Apple Silicon.
    case appleSilicon
    
    /// A localized human-readable variant name.
    public var displayString: String {
        switch self {
        case .appleSilicon:
            return localizeString("Apple Silicon")
        case .universal:
            return localizeString("Universal")
        }
    }
    
    /// The SF Symbol name used to represent this variant.
    public var iconName: String {
        switch self {
            case .appleSilicon:
                return "m4.button.horizontal"
            case .universal:
                return "cpu.fill"
        }
    }

    /// Returns the default variant for the current machine architecture.
    public static func defaultForMachine(machineHardwareName: String? = HostHardware.currentMachineHardwareName()) -> Self {
        HostHardware.isAppleSilicon(machineHardwareName: machineHardwareName) ? .appleSilicon : .universal
    }
}

/// A filter for matching exact architectures or architecture variants.
public enum ArchitectureFilter: Equatable, Hashable, Sendable {
    /// Match an exact architecture-specific artifact.
    case architecture(Architecture)
    /// Match a variant such as universal or Apple Silicon-only.
    case variant(ArchitectureVariant)

    /// Creates a filter from a command-line or persisted raw value.
    public init?(_ rawValue: String) {
        switch rawValue {
        case Architecture.arm64.rawValue:
            self = .architecture(.arm64)
        case Architecture.x86_64.rawValue:
            self = .architecture(.x86_64)
        case ArchitectureVariant.appleSilicon.rawValue, "apple-silicon", "apple_silicon":
            self = .variant(.appleSilicon)
        case ArchitectureVariant.universal.rawValue:
            self = .variant(.universal)
        default:
            return nil
        }
    }

    /// Returns whether the provided architecture list satisfies this filter.
    public func matches(_ architectures: [Architecture]?) -> Bool {
        guard let architectures, !architectures.isEmpty else { return true }

        switch self {
        case .architecture(let architecture):
            return architectures == [architecture]
        case .variant(.appleSilicon):
            return architectures.isAppleSilicon
        case .variant(.universal):
            return architectures.isUniversal
        }
    }
}

extension Array where Element == Architecture {
    /// Whether the array represents an Apple Silicon-only artifact.
    public var isAppleSilicon: Bool {
        self == [.arm64]
    }
    
    /// Whether the array contains both Apple Silicon and Intel support.
    public var isUniversal: Bool {
        self.contains([.arm64, .x86_64])
    }

    /// Returns whether the array contains any of the provided architectures.
    public func containsAny(_ architectures: [Architecture]) -> Bool {
        !Set(self).isDisjoint(with: architectures)
    }

    var listOutputSuffix: String {
        guard !isEmpty else { return "" }
        if isUniversal {
            return " [\(ArchitectureVariant.universal.displayString)]"
        }
        if isAppleSilicon {
            return " [\(ArchitectureVariant.appleSilicon.displayString)]"
        }
        return " [\(map(\.displayString).joined(separator: "|"))]"
    }
}

extension Array where Element == ArchitectureFilter {
    /// Returns the default filter list for the current machine.
    public static func defaultForMachine(machineHardwareName: String? = HostHardware.currentMachineHardwareName()) -> [ArchitectureFilter] {
        [.variant(.defaultForMachine(machineHardwareName: machineHardwareName))]
    }

    func matches(_ architectures: [Architecture]?) -> Bool {
        guard !isEmpty else { return true }
        return contains { $0.matches(architectures) }
    }
}
