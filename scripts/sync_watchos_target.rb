#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = ENV.fetch(
  "RALLYMATE_XCODE_PROJECT",
  File.join(ROOT, "apps/rallymate/ios/Runner.xcodeproj")
)
WATCH_GROUP_PATH = "../../../wear/watchos/RallyMateWatchApp"
WATCH_PACKAGE_PATH = "../../../wear/watchos/RallyMateCore"
WATCH_CORE_SOURCE_PATH = "#{WATCH_PACKAGE_PATH}/Sources/RallyMateCore"
WATCH_KIT_SOURCE_PATH = "#{WATCH_PACKAGE_PATH}/Sources/RallyMateWatchKit"
WATCH_MASCOT_PATH = "#{WATCH_KIT_SOURCE_PATH}/Resources/Mascot"
WATCH_BACKGROUNDS_PATH = "#{WATCH_KIT_SOURCE_PATH}/Resources/Backgrounds"
WATCH_TARGET_NAME = "RallyMateWatchApp"
WATCH_BUNDLE_ID = "com.rallymate.rallymate.watchkitapp"

def ensure_file(group, path)
  group.files.find { |file| file.path == path } || group.new_file(path)
end

def ensure_build_file(phase, reference)
  phase.files.find { |file| file.file_ref == reference } ||
    phase.add_file_reference(reference, true)
end

def ensure_group(parent, name, path)
  group = parent.groups.find { |candidate| candidate.display_name == name }
  group ||= parent.new_group(name, path)
  group.path = path
  group.source_tree = "<group>"
  group
end

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |target| target.name == "Runner" }
abort("Runner target not found in #{PROJECT_PATH}") unless runner

team = ENV["DEVELOPMENT_TEAM"]
team ||= runner.build_configurations
  .filter_map { |config| config.build_settings["DEVELOPMENT_TEAM"] }
  .find { |value| !value.to_s.empty? }

watch_target = project.targets.find { |target| target.name == WATCH_TARGET_NAME }
watch_target ||= project.new_target(
  :application,
  WATCH_TARGET_NAME,
  :watchos,
  "10.0"
)
# Modern SwiftUI watchOS apps are executable application targets. The legacy
# watchapp2 product type creates a stub binary and conflicts with Swift sources.
watch_target.product_type = "com.apple.product-type.application"
unless watch_target.build_configurations.any? { |config| config.name == "Profile" }
  watch_target.add_build_configuration("Profile", :release)
end

watch_group = project.main_group.groups.find do |group|
  group.display_name == WATCH_TARGET_NAME
end
watch_group ||= project.main_group.new_group(WATCH_TARGET_NAME, WATCH_GROUP_PATH)
watch_group.path = WATCH_GROUP_PATH
watch_group.source_tree = "<group>"

watch_source = ensure_file(watch_group, "RallyMateWatchApp.swift")
watch_info = ensure_file(watch_group, "Info.plist")
watch_entitlements = ensure_file(watch_group, "RallyMateWatchApp.entitlements")
watch_assets = ensure_file(watch_group, "Assets.xcassets")
watch_privacy = ensure_file(watch_group, "PrivacyInfo.xcprivacy")

ensure_build_file(watch_target.source_build_phase, watch_source)
ensure_build_file(watch_target.resources_build_phase, watch_assets)
ensure_build_file(watch_target.resources_build_phase, watch_privacy)

# Flutter invokes xcodebuild with a shared BUILD_DIR and an iPhone SDK override.
# A cross-platform local Swift package then links its watch objects from the
# iPhone output folder. Reference the package's canonical source files directly
# in the embedded target; SwiftPM remains the source of truth for host tests.
watch_target.frameworks_build_phase.files.select do |file|
  file.product_ref&.product_name == "RallyMateWatchKit"
end.each(&:remove_from_project)
watch_target.package_product_dependencies.select do |dependency|
  dependency.product_name == "RallyMateWatchKit"
end.each(&:remove_from_project)
project.root_object.package_references.select do |reference|
  reference.respond_to?(:relative_path) && reference.relative_path == WATCH_PACKAGE_PATH
end.each(&:remove_from_project)

project_dir = File.dirname(PROJECT_PATH)
[
  ["RallyMateCore Sources", WATCH_CORE_SOURCE_PATH],
  ["RallyMateWatchKit Sources", WATCH_KIT_SOURCE_PATH],
].each do |name, relative_path|
  group = ensure_group(project.main_group, name, relative_path)
  Dir.glob(File.expand_path("*.swift", File.join(project_dir, relative_path))).sort.each do |path|
    reference = ensure_file(group, File.basename(path))
    ensure_build_file(watch_target.source_build_phase, reference)
  end
end

mascot_group = ensure_group(project.main_group, "RallyMateWatch Mascot", WATCH_MASCOT_PATH)
Dir.glob(File.expand_path("*.png", File.join(project_dir, WATCH_MASCOT_PATH))).sort.each do |path|
  reference = ensure_file(mascot_group, File.basename(path))
  ensure_build_file(watch_target.resources_build_phase, reference)
end

background_group = ensure_group(
  project.main_group,
  "RallyMateWatch Backgrounds",
  WATCH_BACKGROUNDS_PATH
)
Dir.glob(File.expand_path("*.png", File.join(project_dir, WATCH_BACKGROUNDS_PATH))).sort.each do |path|
  reference = ensure_file(background_group, File.basename(path))
  ensure_build_file(watch_target.resources_build_phase, reference)
end

common_settings = {
  "APPLICATION_EXTENSION_API_ONLY" => "NO",
  "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
  "CODE_SIGN_ENTITLEMENTS" => "#{WATCH_GROUP_PATH}/RallyMateWatchApp.entitlements",
  "CODE_SIGN_STYLE" => "Automatic",
  "CURRENT_PROJECT_VERSION" => "$(FLUTTER_BUILD_NUMBER)",
  "ENABLE_PREVIEWS" => "YES",
  "GENERATE_INFOPLIST_FILE" => "NO",
  "INFOPLIST_FILE" => "#{WATCH_GROUP_PATH}/Info.plist",
  "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks",
  "MARKETING_VERSION" => "$(FLUTTER_BUILD_NAME)",
  "PRODUCT_BUNDLE_IDENTIFIER" => WATCH_BUNDLE_ID,
  "PRODUCT_NAME" => "$(TARGET_NAME)",
  "SDKROOT" => "watchos",
  "SKIP_INSTALL" => "YES",
  "SUPPORTED_PLATFORMS" => "watchos watchsimulator",
  "SWIFT_EMIT_LOC_STRINGS" => "YES",
  "SWIFT_VERSION" => "5.9",
  "TARGETED_DEVICE_FAMILY" => "4",
  "WATCHOS_DEPLOYMENT_TARGET" => "10.0"
}
common_settings["DEVELOPMENT_TEAM"] = team if team && !team.empty?
generated_config = project.files.find do |file|
  file.path == "Flutter/Generated.xcconfig" || file.path == "Generated.xcconfig"
end
abort("Flutter/Generated.xcconfig reference not found") unless generated_config
watch_target.build_configurations.each do |configuration|
  configuration.base_configuration_reference = generated_config
  configuration.build_settings.merge!(common_settings)
end

target_attributes = project.root_object.attributes["TargetAttributes"] ||= {}
target_attributes[watch_target.uuid] ||= {}
target_attributes[watch_target.uuid].merge!(
  "CreatedOnToolsVersion" => "26.0",
  "ProvisioningStyle" => "Automatic"
)

runner.add_dependency(watch_target) unless runner.dependency_for_target(watch_target)
embed_phase = runner.copy_files_build_phases.find do |phase|
  phase.name == "Embed Watch Content"
end
embed_phase ||= runner.new_copy_files_build_phase("Embed Watch Content")
embed_phase.dst_subfolder_spec = "16"
embed_phase.dst_path = "$(CONTENTS_FOLDER_PATH)/Watch"
embedded_product = ensure_build_file(embed_phase, watch_target.product_reference)
embedded_product.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

# Flutter's Thin Binary and CocoaPods embedding phases mutate Runner.app. Keep
# the watch copy ahead of those scripts to avoid a dependency cycle through the
# processed Runner Info.plist.
runner.build_phases.delete(embed_phase)
thin_binary_index = runner.build_phases.index do |phase|
  phase.respond_to?(:name) && phase.name == "Thin Binary"
end
runner.build_phases.insert(thin_binary_index || runner.build_phases.length, embed_phase)

runner_group = project.main_group.groups.find { |group| group.display_name == "Runner" }
abort("Runner source group not found") unless runner_group
phone_queue = ensure_file(runner_group, "Watch/AppleWatchEventQueue.swift")
ensure_build_file(runner.source_build_phase, phone_queue)

project.save

watch_scheme = Xcodeproj::XCScheme.new
watch_scheme.add_build_target(watch_target)
watch_scheme.set_launch_target(watch_target)
watch_scheme.save_as(PROJECT_PATH, WATCH_TARGET_NAME, true)

puts "Synced #{WATCH_TARGET_NAME} into #{PROJECT_PATH}"
puts "Signing team: #{team || '(set DEVELOPMENT_TEAM before device builds)'}"
