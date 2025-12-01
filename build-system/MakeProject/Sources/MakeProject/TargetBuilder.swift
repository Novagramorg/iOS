import Foundation
import PathKit
import XcodeProj

class TargetBuilder {
    let project: PBXProject
    let pbxproj: PBXProj
    let mainGroup: PBXGroup
    let outputDir: Path
    let symlinkManager: SymlinkManager

    private var targetsByName: [String: PBXNativeTarget] = [:]
    private var groupsByPath: [String: PBXGroup] = [:]

    init(project: PBXProject, pbxproj: PBXProj, mainGroup: PBXGroup, outputDir: Path, symlinkManager: SymlinkManager) {
        self.project = project
        self.pbxproj = pbxproj
        self.mainGroup = mainGroup
        self.outputDir = outputDir
        self.symlinkManager = symlinkManager
    }

    func buildTarget(for module: ModuleDefinition, allModules: [String: ModuleDefinition]) throws -> PBXNativeTarget? {
        guard let moduleType = ModuleType(from: module) else {
            print("Warning: Unknown module type \(module.type) for \(module.name)")
            return nil
        }

        // Skip empty modules
        let sourceFiles = module.sources.filter { !$0.hasSuffix(".a") }
        if sourceFiles.isEmpty && moduleType != .xcframework {
            return nil
        }

        switch moduleType {
        case .xcframework:
            return try buildXCFrameworkTarget(for: module)
        case .swiftLibrary, .objcLibrary, .ccLibrary:
            return try buildFrameworkTarget(for: module, moduleType: moduleType)
        }
    }

    private func buildXCFrameworkTarget(for module: ModuleDefinition) throws -> PBXNativeTarget {
        // For xcframeworks, we create a reference but no build phases
        let target = PBXNativeTarget(
            name: module.name,
            buildConfigurationList: createConfigurationList(for: module, isXCFramework: true),
            buildPhases: [],
            productName: module.name,
            productType: .framework
        )
        pbxproj.add(object: target)
        project.targets.append(target)
        targetsByName[module.name] = target
        return target
    }

    private func buildFrameworkTarget(for module: ModuleDefinition, moduleType: ModuleType) throws -> PBXNativeTarget {
        // Create group for module
        let moduleGroup = try getOrCreateGroup(for: module.path)

        // Create symlinks and file references
        var sourceRefs: [PBXFileReference] = []
        var headerRefs: [PBXFileReference] = []

        let allSourceFiles = module.sources + (module.hdrs ?? []) + (module.textualHdrs ?? [])

        for source in allSourceFiles {
            if source.hasSuffix(".a") { continue }

            let sourcePath = Path(source)
            let fileName = sourcePath.lastComponent

            // Calculate relative path within module
            let relativeToModule: String
            if source.hasPrefix(module.path + "/") {
                relativeToModule = String(source.dropFirst(module.path.count + 1))
            } else if source.hasPrefix("bazel-out/") {
                // Generated file
                if let range = source.range(of: module.path + "/") {
                    relativeToModule = String(source[range.upperBound...])
                } else {
                    relativeToModule = fileName
                }
            } else {
                relativeToModule = fileName
            }

            // Create symlink
            let symlinkPath = outputDir + module.path + relativeToModule
            try symlinkManager.createDirectory(symlinkPath.parent())
            try symlinkManager.createSymlink(from: Path(source), to: symlinkPath)

            // Create file reference
            let fileRef = try getOrCreateFileReference(
                path: relativeToModule,
                in: moduleGroup,
                modulePath: module.path,
                fileName: fileName
            )

            if source.hasSuffix(".h") || source.hasSuffix(".hpp") {
                headerRefs.append(fileRef)
            } else if !source.hasSuffix(".inc") {
                sourceRefs.append(fileRef)
            }
        }

        // Build phases
        var buildPhases: [PBXBuildPhase] = []

        // Sources build phase
        let sourcesBuildPhase = PBXSourcesBuildPhase(
            files: sourceRefs.map { ref in
                let buildFile = PBXBuildFile(file: ref)
                pbxproj.add(object: buildFile)
                return buildFile
            }
        )
        pbxproj.add(object: sourcesBuildPhase)
        buildPhases.append(sourcesBuildPhase)

        // Headers build phase for ObjC/C++
        if moduleType == .objcLibrary || moduleType == .ccLibrary {
            let headersBuildPhase = PBXHeadersBuildPhase(
                files: headerRefs.map { ref in
                    let buildFile = PBXBuildFile(file: ref, settings: ["ATTRIBUTES": ["Public"]])
                    pbxproj.add(object: buildFile)
                    return buildFile
                }
            )
            pbxproj.add(object: headersBuildPhase)
            buildPhases.append(headersBuildPhase)
        }

        // Frameworks build phase
        let frameworksBuildPhase = PBXFrameworksBuildPhase(files: [])
        pbxproj.add(object: frameworksBuildPhase)
        buildPhases.append(frameworksBuildPhase)

        // Create target
        let configList = createConfigurationList(for: module, isXCFramework: false)

        let target = PBXNativeTarget(
            name: module.name,
            buildConfigurationList: configList,
            buildPhases: buildPhases,
            productName: module.name,
            productType: .framework
        )
        pbxproj.add(object: target)
        project.targets.append(target)
        targetsByName[module.name] = target

        return target
    }

    func wireUpDependencies(modules: [String: ModuleDefinition]) throws {
        for (name, module) in modules {
            guard let target = targetsByName[name],
                  let deps = module.deps else { continue }

            // Find frameworks build phase
            guard let frameworksPhase = target.buildPhases.compactMap({ $0 as? PBXFrameworksBuildPhase }).first else {
                continue
            }

            for depName in deps {
                guard let depTarget = targetsByName[depName] else { continue }

                // Add target dependency
                let dependency = PBXTargetDependency(target: depTarget)
                pbxproj.add(object: dependency)
                target.dependencies.append(dependency)
            }

            // Add SDK frameworks
            if let sdkFrameworks = module.sdkFrameworks {
                for framework in sdkFrameworks {
                    let fileRef = PBXFileReference(
                        sourceTree: .sdkRoot,
                        name: "\(framework).framework",
                        lastKnownFileType: "wrapper.framework",
                        path: "System/Library/Frameworks/\(framework).framework"
                    )
                    pbxproj.add(object: fileRef)
                    let buildFile = PBXBuildFile(file: fileRef)
                    pbxproj.add(object: buildFile)
                    frameworksPhase.files?.append(buildFile)
                }
            }
        }
    }

    func getTarget(named name: String) -> PBXNativeTarget? {
        return targetsByName[name]
    }

    private func createConfigurationList(for module: ModuleDefinition, isXCFramework: Bool) -> XCConfigurationList {
        let debugSettings = createBuildSettings(for: module, isDebug: true, isXCFramework: isXCFramework)
        let releaseSettings = createBuildSettings(for: module, isDebug: false, isXCFramework: isXCFramework)

        let debugConfig = XCBuildConfiguration(name: "Debug", buildSettings: debugSettings)
        let releaseConfig = XCBuildConfiguration(name: "Release", buildSettings: releaseSettings)

        pbxproj.add(object: debugConfig)
        pbxproj.add(object: releaseConfig)

        let configList = XCConfigurationList(
            buildConfigurations: [debugConfig, releaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: configList)

        return configList
    }

    private func createBuildSettings(for module: ModuleDefinition, isDebug: Bool, isXCFramework: Bool) -> BuildSettings {
        var settings: BuildSettings = [
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.\(module.name)",
            "INFOPLIST_FILE": "",
            "SKIP_INSTALL": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
        ]

        let moduleType = ModuleType(from: module)

        // Swift settings
        if moduleType == .swiftLibrary {
            settings["SWIFT_VERSION"] = "5.0"

            if let copts = module.copts, !copts.isEmpty {
                let filtered = copts.filter { !$0.hasPrefix("-warnings") }
                if !filtered.isEmpty {
                    settings["OTHER_SWIFT_FLAGS"] = "$(inherited) " + filtered.joined(separator: " ")
                }
            }

            if let defines = module.defines, !defines.isEmpty {
                settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) " + defines.joined(separator: " ")
            }
        }

        // C/ObjC settings
        if moduleType == .objcLibrary || moduleType == .ccLibrary {
            if let copts = module.copts, !copts.isEmpty {
                let filtered = copts.filter { !$0.hasPrefix("-warnings") && !$0.hasPrefix("-W") }
                if !filtered.isEmpty {
                    settings["OTHER_CFLAGS"] = "$(inherited) " + filtered.joined(separator: " ")
                }
            }

            if let cxxopts = module.cxxopts, !cxxopts.isEmpty {
                let filtered = cxxopts.filter { !$0.hasPrefix("-std=") }
                if !filtered.isEmpty {
                    settings["OTHER_CPLUSPLUSFLAGS"] = "$(inherited) " + filtered.joined(separator: " ")
                }
            }

            if let defines = module.defines, !defines.isEmpty {
                settings["GCC_PREPROCESSOR_DEFINITIONS"] = "$(inherited) " + defines.joined(separator: " ")
            }

            if let includes = module.includes, !includes.isEmpty {
                let paths = includes.map { inc -> String in
                    if inc == "." {
                        return "$(SRCROOT)/\(module.path)"
                    }
                    return "$(SRCROOT)/\(module.path)/\(inc)"
                }
                settings["HEADER_SEARCH_PATHS"] = "$(inherited) " + paths.joined(separator: " ")
            }
        }

        return settings
    }

    private func getOrCreateGroup(for path: String) throws -> PBXGroup {
        if let existing = groupsByPath[path] {
            return existing
        }

        let components = path.split(separator: "/").map(String.init)
        var currentGroup = mainGroup
        var currentPath = ""

        for component in components {
            currentPath = currentPath.isEmpty ? component : currentPath + "/" + component

            if let existing = groupsByPath[currentPath] {
                currentGroup = existing
            } else {
                let newGroup = PBXGroup(children: [], sourceTree: .group, name: component, path: component)
                pbxproj.add(object: newGroup)
                currentGroup.children.append(newGroup)
                groupsByPath[currentPath] = newGroup
                currentGroup = newGroup
            }
        }

        return currentGroup
    }

    private func getOrCreateFileReference(path: String, in group: PBXGroup, modulePath: String, fileName: String) throws -> PBXFileReference {
        let pathComponents = path.split(separator: "/").map(String.init)

        var currentGroup = group
        var currentPath = modulePath

        // Navigate/create intermediate groups
        for component in pathComponents.dropLast() {
            currentPath = currentPath + "/" + component
            if let existing = groupsByPath[currentPath] {
                currentGroup = existing
            } else {
                let newGroup = PBXGroup(children: [], sourceTree: .group, name: component, path: component)
                pbxproj.add(object: newGroup)
                currentGroup.children.append(newGroup)
                groupsByPath[currentPath] = newGroup
                currentGroup = newGroup
            }
        }

        // Create file reference
        let fileType = lastKnownFileType(for: fileName)
        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: fileName,
            lastKnownFileType: fileType,
            path: fileName
        )
        pbxproj.add(object: fileRef)
        currentGroup.children.append(fileRef)

        return fileRef
    }

    private func lastKnownFileType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "sourcecode.swift"
        case "m": return "sourcecode.c.objc"
        case "mm": return "sourcecode.cpp.objcpp"
        case "c": return "sourcecode.c.c"
        case "cc", "cpp", "cxx": return "sourcecode.cpp.cpp"
        case "h": return "sourcecode.c.h"
        case "hpp": return "sourcecode.cpp.h"
        case "metal": return "sourcecode.metal"
        case "json": return "text.json"
        case "plist": return "text.plist.xml"
        default: return "text"
        }
    }
}
