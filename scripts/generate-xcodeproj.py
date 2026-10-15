#!/usr/bin/env python3
"""Write PhoneScreen.xcodeproj from the source tree. Deterministic ids."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT_FILES = sorted((ROOT / "Sources").rglob("*.swift"))
OBJC_FILES = sorted((ROOT / "Sources").rglob("*.m"))
HEADER = ROOT / "Sources/VirtualDisplaySPI/include/VirtualDisplaySPI.h"
BRIDGING = ROOT / "Sources/PhoneScreen/PhoneScreen-Bridging-Header.h"
PLIST = ROOT / "Support/Info.plist"


def oid(*parts: str) -> str:
    digest = hashlib.sha1("::".join(parts).encode()).hexdigest()[:24].upper()
    return digest


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


swift_refs = []
for path in SWIFT_FILES:
    swift_refs.append((oid("file", rel(path)), oid("build", rel(path)), rel(path), path.name))

objc_refs = []
for path in OBJC_FILES:
    objc_refs.append((oid("file", rel(path)), oid("build", rel(path)), rel(path), path.name))

header_ref = oid("file", rel(HEADER))
bridging_ref = oid("file", rel(BRIDGING))
plist_ref = oid("file", rel(PLIST))

target = oid("target")
product = oid("product")
project = oid("project")
sources_phase = oid("phase", "sources")
frameworks_phase = oid("phase", "frameworks")
target_list = oid("list", "target")
project_list = oid("list", "project")
target_debug = oid("cfg", "target", "debug")
target_release = oid("cfg", "target", "release")
project_debug = oid("cfg", "project", "debug")
project_release = oid("cfg", "project", "release")
main_group = oid("group", "main")
core_group = oid("group", "core")
app_group = oid("group", "app")
spi_group = oid("group", "spi")
support_group = oid("group", "support")
products_group = oid("group", "products")

core_files = [item for item in swift_refs if item[2].startswith("Sources/PhoneScreenCore/")]
app_files = [item for item in swift_refs if item[2].startswith("Sources/PhoneScreen/")]

file_entries = []
for ref, _build, path, _name in swift_refs:
    file_entries.append(
        f"\t\t{ref} /* {Path(path).name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {Path(path).name}; sourceTree = \"<group>\"; }};"
    )
for ref, _build, path, _name in objc_refs:
    file_entries.append(
        f"\t\t{ref} /* {Path(path).name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = {Path(path).name}; sourceTree = \"<group>\"; }};"
    )
file_entries.append(
    f"\t\t{header_ref} /* VirtualDisplaySPI.h */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; name = VirtualDisplaySPI.h; path = Sources/VirtualDisplaySPI/include/VirtualDisplaySPI.h; sourceTree = SOURCE_ROOT; }};"
)
file_entries.append(
    f"\t\t{bridging_ref} /* PhoneScreen-Bridging-Header.h */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.c.h; path = PhoneScreen-Bridging-Header.h; sourceTree = \"<group>\"; }};"
)
file_entries.append(
    f"\t\t{plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};"
)
file_entries.append(
    f"\t\t{product} /* PhoneScreen.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PhoneScreen.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)

build_files = []
for _ref, build, path, _name in swift_refs + objc_refs:
    build_files.append(
        f"\t\t{build} /* {Path(path).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {_ref} /* {Path(path).name} */; }};"
    )

sources_children = "\n".join(
    f"\t\t\t\t{build} /* {Path(path).name} in Sources */,"
    for _ref, build, path, _name in swift_refs + objc_refs
)

def group_children(items, extra=""):
    lines = [f"\t\t\t\t{ref} /* {Path(path).name} */," for ref, _b, path, _n in items]
    if extra:
        lines.append(extra)
    return "\n".join(lines)

core_children = group_children(core_files)
app_children = group_children(
    app_files,
    f"\t\t\t\t{bridging_ref} /* PhoneScreen-Bridging-Header.h */,",
)
spi_children = "\n".join(
    [
        f"\t\t\t\t{objc_refs[0][0]} /* VirtualDisplaySPI.m */,",
        f"\t\t\t\t{header_ref} /* VirtualDisplaySPI.h */,",
    ]
)

target_settings = """
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Manual;
				CODE_SIGNING_REQUIRED = NO;
				COMBINE_HIDPI_IMAGES = YES;
				ENABLE_APP_SANDBOX = NO;
				ENABLE_HARDENED_RUNTIME = NO;
				GENERATE_INFOPLIST_FILE = NO;
				HEADER_SEARCH_PATHS = (
					"$(SRCROOT)/Sources/VirtualDisplaySPI/include",
				);
				INFOPLIST_FILE = Support/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				OTHER_LDFLAGS = (
					"-framework",
					AppKit,
					"-framework",
					CoreGraphics,
					"-framework",
					Carbon,
					"-framework",
					ServiceManagement,
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.phonescreen.app;
				PRODUCT_NAME = PhoneScreen;
				SDKROOT = macosx;
				SWIFT_OBJC_BRIDGING_HEADER = Sources/PhoneScreen/PhoneScreen-Bridging-Header.h;
				SWIFT_VERSION = 5.0;
"""

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_entries)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{core_group} /* PhoneScreenCore */ = {{
			isa = PBXGroup;
			children = (
{core_children}
			);
			path = PhoneScreenCore;
			sourceTree = "<group>";
		}};
		{app_group} /* PhoneScreen */ = {{
			isa = PBXGroup;
			children = (
{app_children}
			);
			path = PhoneScreen;
			sourceTree = "<group>";
		}};
		{spi_group} /* VirtualDisplaySPI */ = {{
			isa = PBXGroup;
			children = (
{spi_children}
			);
			name = VirtualDisplaySPI;
			path = VirtualDisplaySPI;
			sourceTree = "<group>";
		}};
		{support_group} /* Support */ = {{
			isa = PBXGroup;
			children = (
				{plist_ref} /* Info.plist */,
			);
			path = Support;
			sourceTree = "<group>";
		}};
		{products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product} /* PhoneScreen.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{main_group} = {{
			isa = PBXGroup;
			children = (
				{oid("group", "sources")} /* Sources */,
				{support_group} /* Support */,
				{products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{oid("group", "sources")} /* Sources */ = {{
			isa = PBXGroup;
			children = (
				{core_group} /* PhoneScreenCore */,
				{app_group} /* PhoneScreen */,
				{spi_group} /* VirtualDisplaySPI */,
			);
			path = Sources;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* PhoneScreen */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_list} /* Build configuration list for PBXNativeTarget "PhoneScreen" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = PhoneScreen;
			productName = PhoneScreen;
			productReference = {product} /* PhoneScreen.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeVersion = 1500;
			}};
			buildConfigurationList = {project_list} /* Build configuration list for PBXProject "PhoneScreen" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				"zh-Hans",
				Base,
			);
			mainGroup = {main_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* PhoneScreen */,
			);
		}};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_children}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{project_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{project_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
			}};
			name = Release;
		}};
		{target_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{target_settings}
			}};
			name = Debug;
		}};
		{target_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{target_settings}
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{project_list} /* Build configuration list for PBXProject "PhoneScreen" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{project_debug} /* Debug */,
				{project_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_list} /* Build configuration list for PBXNativeTarget "PhoneScreen" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{target_debug} /* Debug */,
				{target_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
"""

project_dir = ROOT / "PhoneScreen.xcodeproj"
project_dir.mkdir(exist_ok=True)
(project_dir / "project.pbxproj").write_text(pbx, encoding="utf-8")

scheme_dir = project_dir / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "PhoneScreen.app"
               BlueprintName = "PhoneScreen"
               ReferencedContainer = "container:PhoneScreen.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "{target}"
         BuildableName = "PhoneScreen.app"
         BlueprintName = "PhoneScreen"
         ReferencedContainer = "container:PhoneScreen.xcodeproj">
      </BuildableReference>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableReference
         BuildableIdentifier = "primary"
         BlueprintIdentifier = "{target}"
         BuildableName = "PhoneScreen.app"
         BlueprintName = "PhoneScreen"
         ReferencedContainer = "container:PhoneScreen.xcodeproj">
      </BuildableReference>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
(scheme_dir / "PhoneScreen.xcscheme").write_text(scheme, encoding="utf-8")

workspace = project_dir / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text(
    """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
    encoding="utf-8",
)
print(f"wrote {project_dir / 'project.pbxproj'}")
