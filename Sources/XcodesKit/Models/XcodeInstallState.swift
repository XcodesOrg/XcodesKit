//
//  InstallState.swift
//  
//
//  Created by Matt Kiazyk on 2023-06-06.
//

import Foundation
@preconcurrency import Path

/// The installation state of an Xcode list item.
public enum XcodeInstallState: Equatable, Sendable {
    /// The Xcode is available but not installed.
    case notInstalled
    /// The Xcode is currently moving through an installation step.
    case installing(XcodeInstallationStep)
    /// The Xcode is installed at the associated path.
    case installed(Path)
    /// The Xcode at the associated path is being uninstalled.
    case uninstalling(Path)

    /// Whether the state is ``notInstalled``.
    public var notInstalled: Bool {
        switch self {
        case .notInstalled: return true
        default: return false
        }
    }
    /// Whether the state is ``installing(_:)``.
    public var installing: Bool {
        switch self {
        case .installing: return true
        default: return false
        }
    }
    /// Whether the state is ``installed(_:)``.
    public var installed: Bool {
        switch self {
        case .installed: return true
        default: return false
        }
    }
    /// Whether the state is ``uninstalling(_:)``.
    public var uninstalling: Bool {
        switch self {
        case .uninstalling: return true
        default: return false
        }
    }

    /// The installed path when the state is ``installed(_:)`` or ``uninstalling(_:)``.
    public var installedPath: Path? {
        switch self {
        case .installed(let path): return path
        case .uninstalling(let path): return path
        default: return nil
        }
    }
}
