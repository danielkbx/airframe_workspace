# Airframe Handoff: Unit Formatters and SwiftUI Value Views

Last updated: 2026-07-12

## Current Mode / Important Constraint

If a future chat starts in Plan Mode, do not edit files yet. First confirm that implementation is allowed, or wait until Plan Mode is ended by a developer message.

## Workspace

Workspace root:
`/Users/daniel/Projekte/Airframe`

Airframe repo:
`/Users/daniel/Projekte/Airframe/Airframe`

Before doing any work, read:

1. `.agents/README.md`
2. `.agents/MEMORY.md`
3. `.agents/RESEARCH.md`
4. `.agents/ARCHITECTURE.md`
5. `.agents/TASKS.md`
6. `.agents/TOOLING.md`
7. `.agents/PLAN.md`
8. `.agents/PRINCIPLES.md`
9. `.agents/BACKLOG.md`

Important project rules:

- Project language is English for code, documentation, comments, commit text, and project artifacts.
- Use Swift 5.9 language mode.
- Do not introduce external dependencies without explicit user approval.
- Prefer namespacing with nested types where it improves clarity.
- Put each large type in its own file.
- Use Swift Testing for package tests unless XCTest is specifically needed.
- CLI-first workflow; use `swift` and `xcodebuild`.

## Current User Goal

The user wants unit formatting cleaned up and centralized.

Required direction:

- Do not keep one generic formatter that handles every unit.
- Create one formatter per unit family, for example `DurationFormatter`.
- Each formatter can display multiple units, but receives values in that formatter's base unit.
- For `DurationFormatter`, the base input unit is seconds.
- `DurationFormatter.Unit.auto` should display the largest useful unit combination.
- Example: `63 s` should become `1 min 3 s` or `1 m 3 s`, depending on the final abbreviation style.
- Add one SwiftUI view per unit family in the UI package.
- Those views receive the value plus optional settings, then render `Text` using the formatter.
- Rule going forward: whenever values are displayed in the app, use these value views rather than ad hoc formatting.

## Current Formatting Code

There is an existing helper in:

`Airframe/Packages/AirframeUI/Sources/AirframeUI/MeasurementFormatter.swift`

Observed content:

- `AirframeMeasurementFormatter`
- `MeasurementUnit`
- `MeasurementFormatStyle`
- `FormattedMeasurementText`

This was a first pass and should be replaced or migrated away from. The user explicitly disliked this style because it is too generic. Do not build further on this as the main abstraction.

## Current App DocumentHome Structure

The DocumentHome split is in:

`Airframe/App/Airframe/App/DocumentHome/`

Relevant files observed:

- `DocumentHomeView.swift`
- `Sidebar.swift`
- `LogDetail.swift`
- `IssueList.swift`
- `MetadataRow.swift`
- `Restoration.swift`
- `StatusViews.swift`

The user wanted `DocumentHomeView` as namespace/container. Current naming direction:

- `DocumentHomeView.Sidebar`
- `DocumentHomeView.LogDetail`
- `DocumentHomeView.IssueList`
- `DocumentHomeView.MetadataRow`
- etc.

Preview crashes were seen in SwiftUI's `TableViewListCore_Mac2.swift` around the sidebar preview, likely tied to `List` or outline-style content inside macOS previews. This is separate from the formatter task, but avoid making sidebar preview instability worse.

## Known Reader Units

The reader model exposes these fields in:

`Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ParsedLog.swift`

Useful fields:

- `durationSeconds: Double?`
- `sampleRate: Double?`
- `sampleCount: Int`

The sidebar has recently been changed by the user to show duration per log. Find the current exact code before editing.

## Agreed Architecture

Create a new package for non-UI unit formatting:

`Airframe/Packages/AirframeUnits`

Suggested module/product:

- Package: `AirframeUnits`
- Library product: `AirframeUnits`
- Target: `AirframeUnits`
- Test target: `AirframeUnitsTests`

Reason:

- Formatters are pure domain/infrastructure code and should not depend on SwiftUI.
- `AirframeUI` can depend on `AirframeUnits`.
- App targets can use the SwiftUI value views from `AirframeUI`.

Then update:

`Airframe/Packages/AirframeUI/Package.swift`

to depend on local package:

`../AirframeUnits`

and add `AirframeUnits` as a dependency of the `AirframeUI` target.

Also update the Xcode app project to reference the new package/product where needed. Prefer `xcodeproj` tooling if available and appropriate, or carefully edit the project file only after inspecting existing package reference patterns.

## Planned Formatter APIs

Keep each formatter small, focused, and manually implemented with `Foundation.NumberFormatter` or `FloatingPointFormatStyle` as appropriate.

### DurationFormatter

File:

`Airframe/Packages/AirframeUnits/Sources/AirframeUnits/DurationFormatter.swift`

Suggested API:

```swift
import Foundation

public struct DurationFormatter: Sendable {
    public enum Unit: Sendable, Equatable {
        case microseconds
        case milliseconds
        case seconds
        case minutes
        case hours
        case auto
    }

    public var locale: Locale
    public var unit: Unit
    public var fractionDigits: Int
    public var placeholder: String

    public init(
        locale: Locale = .autoupdatingCurrent,
        unit: Unit = .auto,
        fractionDigits: Int = 0,
        placeholder: String = "-"
    )

    public func string(fromSeconds seconds: Double?) -> String
}
```

Behavior:

- Input is always seconds.
- `nil`, `NaN`, and infinity return the placeholder.
- Non-auto units convert from seconds to the requested unit.
- Auto uses largest useful units:
  - below 1 ms: microseconds
  - below 1 s: milliseconds
  - below 60 s: seconds
  - below 3600 s: minutes + seconds
  - 3600 s and above: hours + minutes + seconds
- For compound auto output, start with whole seconds rounded to nearest second unless a strong reason emerges to keep fractions.
- Omit zero leading components.
- Keep the smallest component when the duration is zero.
- Use locale-aware number formatting for numeric components.
- Decide unit labels once and keep them consistent. User examples mentioned `s`, `min`, `h` and also `1 m 3 s`; prefer `min` for minutes to avoid ambiguity unless user corrects it.

Examples:

- `nil` -> `-`
- `0` -> `0 s`
- `0.00042` -> `420 us` or `420 µs`; because files should stay ASCII when possible, prefer `us` unless existing project style uses `µs`.
- `0.42` -> `420 ms`
- `1` -> `1 s`
- `63` -> `1 min 3 s`
- `3661` -> `1 h 1 min 1 s`

### FrequencyFormatter

File:

`Airframe/Packages/AirframeUnits/Sources/AirframeUnits/FrequencyFormatter.swift`

Suggested API:

```swift
public struct FrequencyFormatter: Sendable {
    public enum Unit: Sendable, Equatable {
        case hertz
        case kilohertz
        case megahertz
        case auto
    }

    public init(
        locale: Locale = .autoupdatingCurrent,
        unit: Unit = .auto,
        fractionDigits: Int = 1,
        placeholder: String = "-"
    )

    public func string(fromHertz hertz: Double?) -> String
}
```

Behavior:

- Input is always hertz.
- Auto:
  - below 1,000: Hz
  - below 1,000,000: kHz
  - otherwise: MHz

### Other Formatters to Add

Create these as needed, prioritizing units already displayed by the app:

- `IntegerFormatter`
- `PercentFormatter`
- `VoltageFormatter`
- `CurrentFormatter`
- `AngleFormatter`
- `AngularRateFormatter`
- `LengthFormatter`
- `CoordinateFormatter`
- `RawValueFormatter`

Do not overbuild all possible units in the first pass. Implement the ones required by existing UI and add compact placeholders for obvious next families only when useful.

## Planned SwiftUI Value Views in AirframeUI

Add one SwiftUI view per unit family in:

`Airframe/Packages/AirframeUI/Sources/AirframeUI/ValueText/`

Suggested files:

- `DurationText.swift`
- `FrequencyText.swift`
- `IntegerText.swift`
- `PercentText.swift`
- `VoltageText.swift`
- `CurrentText.swift`
- `AngleText.swift`
- `AngularRateText.swift`
- `LengthText.swift`
- `CoordinateText.swift`
- `RawValueText.swift`

Minimum useful first pass:

- `DurationText`
- `FrequencyText`
- `IntegerText`

Suggested APIs:

```swift
import AirframeUnits
import SwiftUI

public struct DurationText: View {
    private let seconds: Double?
    private let formatter: DurationFormatter

    public init(
        seconds: Double?,
        unit: DurationFormatter.Unit = .auto,
        fractionDigits: Int = 0,
        placeholder: String = "-"
    ) {
        self.seconds = seconds
        self.formatter = DurationFormatter(unit: unit, fractionDigits: fractionDigits, placeholder: placeholder)
    }

    public var body: some View {
        Text(formatter.string(fromSeconds: seconds))
    }
}
```

Consider also an initializer that accepts a fully configured formatter:

```swift
public init(seconds: Double?, formatter: DurationFormatter)
```

That keeps advanced settings possible without exploding initializer parameters.

## Planned MetadataRow Change

The app's `MetadataRow` likely currently accepts a string value. Change it so rows can render value views.

Preferred generic shape:

```swift
extension DocumentHomeView {
    struct MetadataRow<Value: View>: View {
        let title: String
        let accessibilityIdentifier: String?
        @ViewBuilder let value: () -> Value

        init(
            _ title: String,
            accessibilityIdentifier: String? = nil,
            @ViewBuilder value: @escaping () -> Value
        ) {
            self.title = title
            self.accessibilityIdentifier = accessibilityIdentifier
            self.value = value
        }

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                value()
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
    }
}
```

Also consider a convenience initializer for `String` if it reduces churn:

```swift
extension DocumentHomeView.MetadataRow where Value == Text {
    init(_ title: String, value: String, accessibilityIdentifier: String? = nil) {
        self.init(title, accessibilityIdentifier: accessibilityIdentifier) {
            Text(value)
        }
    }
}
```

## Planned Migration

Search for current ad hoc value formatting:

```sh
cd /Users/daniel/Projekte/Airframe/Airframe
rg "formatted|duration|sampleRate|Hz|seconds|MeasurementFormatter|FormattedMeasurementText" App Packages
```

Replace displayed values with value views:

```swift
DocumentHomeView.MetadataRow("Duration") {
    DurationText(seconds: log.durationSeconds)
}

DocumentHomeView.MetadataRow("Sample Rate") {
    FrequencyText(hertz: log.sampleRate)
}

DocumentHomeView.MetadataRow("Samples") {
    IntegerText(log.sampleCount)
}
```

Keep the views in `AirframeUI`, not in the app target.

## Tests to Add

Add Swift Testing tests in:

`Airframe/Packages/AirframeUnits/Tests/AirframeUnitsTests/`

Minimum test coverage:

- `DurationFormatter` placeholder for nil, NaN, infinity.
- `DurationFormatter` seconds formatting.
- `DurationFormatter` ms/us formatting.
- `DurationFormatter.Unit.auto` for `63 -> 1 min 3 s`.
- `DurationFormatter.Unit.auto` for `3661 -> 1 h 1 min 1 s`.
- `FrequencyFormatter.Unit.auto` for Hz/kHz/MHz.
- Locale behavior with at least `Locale(identifier: "de_DE")` for decimal separators if fractional output is used.

Add lightweight `AirframeUI` tests only if the package already has a test target and snapshot/render testing is not needed. Otherwise formatter tests are enough for this pass.

## Verification Commands

Use these after implementation:

```sh
cd /Users/daniel/Projekte/Airframe/Airframe
swift test --package-path Packages/AirframeUnits
swift test --package-path Packages/AirframeUI
xcodebuild -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' build
```

For simulator-related commands, follow project tooling rules and write logs instead of piping `xcodebuild` output to `grep`.

## Xcode Project Notes

The app project already changed during earlier work. Inspect before editing:

```sh
cd /Users/daniel/Projekte/Airframe/Airframe
git diff -- App/Airframe.xcodeproj/project.pbxproj
```

Do not revert unrelated project changes.

## Dirty Worktree Context

Observed dirty worktree before writing this plan:

```text
 M App/Airframe.xcodeproj/project.pbxproj
 M App/Airframe/App/AirframeApp.swift
 M App/Airframe/App/AirframeLaunchContext.swift
A  App/Airframe/App/DocumentHome/DocumentHomeView.swift
 D App/Airframe/App/DocumentHomeView.swift
 M App/Airframe/App/DocumentView.swift
 M App/Airframe/App/HomeView.swift
 M App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
 M App/AirframeTests/AirframeLaunchContextTests.swift
?? App/Airframe/App/DocumentHome/IssueList.swift
?? App/Airframe/App/DocumentHome/LogDetail.swift
?? App/Airframe/App/DocumentHome/MetadataRow.swift
?? App/Airframe/App/DocumentHome/Restoration.swift
?? App/Airframe/App/DocumentHome/Sidebar.swift
?? App/Airframe/App/DocumentHome/StatusViews.swift
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/ios-icon-1024.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-1024.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-128.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-16.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-256.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-32.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-512.png
?? App/Airframe/Resources/Assets.xcassets/AppIcon.appiconset/mac-icon-64.png
?? Packages/AirframeUI/Sources/AirframeUI/AirframeDocumentModel+Debug.swift
```

Treat these as user or previous-session changes. Do not revert them.

## Package.resolved Warning

The repository has `Airframe/App/Airframe.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` with absolute paths. It has caused issues before. Avoid adding more absolute-path churn unless necessary.

## Acceptance Criteria

Implementation is complete when:

- There is a pure `AirframeUnits` package with focused unit formatters.
- `AirframeUI` exposes value views such as `DurationText`, `FrequencyText`, and `IntegerText`.
- Existing displayed duration and other simple values use those views instead of local string formatting.
- Formatter tests cover duration auto output, invalid values, and frequency auto output.
- Package tests pass.
- The macOS app target builds.
- Existing unrelated dirty worktree changes remain intact.
