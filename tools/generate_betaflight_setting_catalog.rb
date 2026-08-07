#!/usr/bin/env ruby

require "open3"

workspace = File.expand_path("..", __dir__)
betaflight = File.join(workspace, "betaflight")
destination = File.join(
  workspace,
  "Airframe/Packages/FlightController/Sources/FlightController/BetaflightSettingCatalog.swift"
)
hardware_destination = File.join(
  workspace,
  "Airframe/Packages/FlightController/Sources/FlightController/BetaflightHardwareCatalog.swift"
)

generations = [
  ["legacy43", "4.3.2"],
  ["legacy44", "4.4.3"],
  ["legacy45", "4.5.5"],
  ["calendar2025_12", "2025.12.5"],
  ["calendar2026_6", "2026.6.1"],
]

def git_show(repository, revision, path)
  output, status = Open3.capture2("git", "-C", repository, "show", "#{revision}:#{path}")
  abort("Unable to read #{revision}:#{path}") unless status.success?
  output
end

def settings(repository, revision)
  parameters = git_show(repository, revision, "src/main/fc/parameter_names.h")
  source = git_show(repository, revision, "src/main/cli/settings.c")
  definitions = {}
  (parameters + source).scan(/^\s*#define\s+(\w+)\s+"([^"]+)"/) do |name, value|
    definitions[name] = value
  end

  sections = Hash.new { |hash, key| hash[key] = [] }
  in_value_table = false
  source.each_line do |line|
    if line.include?("const clivalue_t valueTable[] = {")
      in_value_table = true
      next
    end
    next unless in_value_table
    break if line.match?(/^};/)

    match = line.match(/\{\s*(?:"([^"]+)"|(\w+))\s*,/)
    next unless match
    name = match[1] || definitions[match[2]]
    next unless name

    section = if line.include?("PROFILE_RATE_VALUE")
      :rate_profile
    elsif line.include?("PROFILE_BATTERY_VALUE")
      :battery_profile
    elsif line.include?("PROFILE_VALUE")
      :pid_profile
    else
      :master
    end
    sections[section] << name
  end
  sections.transform_values { |names| names.uniq.sort }
end

def swift_array(names, indentation: "        ")
  return "[]" if names.empty?
  body = names.map { |name| "#{indentation}    \"#{name}\"," }.join("\n")
  "[\n#{body}\n#{indentation}]"
end

def string_array(source, name)
  match = source.match(/(?:static\s+)?const\s+char\s*\*\s*(?:const\s+)?#{Regexp.escape(name)}(?:\[[^\]]*\])?\s*=\s*\{(.*?)\};/m)
  return [] unless match
  match[1].scan(/"([^"]+)"/).flatten
end

def hardware(repository, revision)
  source_path = revision == "2026.6.1" ? "src/main/sensors/sensors.c" : "src/main/cli/settings.c"
  source = git_show(repository, revision, source_path)
  {
    gyro: string_array(source, "lookupTableGyroHardware"),
    accelerometer: string_array(source, "lookupTableAccHardware"),
    barometer: string_array(source, "lookupTableBaroHardware"),
    magnetometer: string_array(source, "lookupTableMagHardware"),
    rangefinder: string_array(source, "lookupTableRangefinderHardware"),
    optical_flow: string_array(source, "lookupTableOpticalflowHardware"),
  }
end

catalogs = generations.to_h { |name, revision| [name, settings(betaflight, revision)] }

output = <<~SWIFT
  //
  //  BetaflightSettingCatalog.swift
  //  FlightController
  //
  //  Generated from tagged Betaflight source by tools/generate_betaflight_setting_catalog.rb.
  //  SPDX-FileCopyrightText: 2026 mail@danielkbx.com
  //

  import Foundation

  struct BetaflightSettingCatalog: Equatable, Sendable {
      let master: [String]
      let pidProfile: [String]
      let rateProfile: [String]
      let batteryProfile: [String]

      static func catalog(for version: FirmwareVersion) -> Self? {
          switch version {
          case .legacy(major: 4, minor: 3, patch: _):
              return .legacy43
          case .legacy(major: 4, minor: 4, patch: _):
              return .legacy44
          case .legacy(major: 4, minor: 5, patch: _):
              return .legacy45
          case .calendar(year: 2025, month: 12, patch: _, fullText: _):
              return .calendar2025_12
          case .calendar(year: 2026, month: 6, patch: _, fullText: _):
              return .calendar2026_6
          default:
              return nil
          }
      }

SWIFT

generations.each do |name, revision|
  catalog = catalogs.fetch(name)
  output << "    // Betaflight #{revision}\n"
  output << "    private static let #{name} = Self(\n"
  output << "        master: #{swift_array(catalog.fetch(:master, []))},\n"
  output << "        pidProfile: #{swift_array(catalog.fetch(:pid_profile, []))},\n"
  output << "        rateProfile: #{swift_array(catalog.fetch(:rate_profile, []))},\n"
  output << "        batteryProfile: #{swift_array(catalog.fetch(:battery_profile, []))}\n"
  output << "    )\n\n"
end

output << "}\n"
File.write(destination, output)

hardware_catalogs = generations.to_h { |name, revision| [name, hardware(betaflight, revision)] }
legacy_mcu_names = string_array(git_show(betaflight, "4.5.5", "src/main/cli/cli.c"), "mcuTypeNames")

hardware_output = <<~SWIFT
  //
  //  BetaflightHardwareCatalog.swift
  //  FlightController
  //
  //  Generated from tagged Betaflight source by tools/generate_betaflight_setting_catalog.rb.
  //  SPDX-FileCopyrightText: 2026 mail@danielkbx.com
  //

  import Foundation

  struct BetaflightHardwareCatalog: Equatable, Sendable {
      let gyroscope: [String]
      let accelerometer: [String]
      let barometer: [String]
      let magnetometer: [String]
      let rangefinder: [String]
      let opticalFlow: [String]

      static func catalog(for version: FirmwareVersion) -> Self? {
          switch version {
          case .legacy(major: 4, minor: 3, patch: _):
              return .legacy43
          case .legacy(major: 4, minor: 4, patch: _):
              return .legacy44
          case .legacy(major: 4, minor: 5, patch: _):
              return .legacy45
          case .calendar(year: 2025, month: 12, patch: _, fullText: _):
              return .calendar2025_12
          case .calendar(year: 2026, month: 6, patch: _, fullText: _):
              return .calendar2026_6
          default:
              return nil
          }
      }

      static func legacyMCUName(id: UInt8) -> String? {
          legacyMCUNames.indices.contains(Int(id)) ? legacyMCUNames[Int(id)] : nil
      }

      private static let legacyMCUNames = #{swift_array(legacy_mcu_names, indentation: "    ")}

SWIFT

generations.each do |name, revision|
  catalog = hardware_catalogs.fetch(name)
  hardware_output << "    // Betaflight #{revision}\n"
  hardware_output << "    private static let #{name} = Self(\n"
  hardware_output << "        gyroscope: #{swift_array(catalog.fetch(:gyro, []))},\n"
  hardware_output << "        accelerometer: #{swift_array(catalog.fetch(:accelerometer, []))},\n"
  hardware_output << "        barometer: #{swift_array(catalog.fetch(:barometer, []))},\n"
  hardware_output << "        magnetometer: #{swift_array(catalog.fetch(:magnetometer, []))},\n"
  hardware_output << "        rangefinder: #{swift_array(catalog.fetch(:rangefinder, []))},\n"
  hardware_output << "        opticalFlow: #{swift_array(catalog.fetch(:optical_flow, []))}\n"
  hardware_output << "    )\n\n"
end

hardware_output << "}\n"
File.write(hardware_destination, hardware_output)
