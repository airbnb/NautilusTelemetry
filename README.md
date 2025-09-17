# NautilusTelemetry

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fairbnb%2FNautilusTelemetry%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/airbnb/NautilusTelemetry) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fairbnb%2FNautilusTelemetry%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/airbnb/NautilusTelemetry) [![Swift](https://github.com/airbnb/NautilusTelemetry/actions/workflows/swift.yml/badge.svg)](https://github.com/airbnb/NautilusTelemetry/actions/workflows/swift.yml)

NautilusTelemetry is an iOS-oriented Swift package to collect [OpenTelemetry](https://github.com/open-telemetry) data and submit it in [OTLP-JSON](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/otlp.md) format to an [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) instance. gRPC is not currently supported in order to keep the package size as small as possible. Not all features of OpenTelemetry are supported; tracing is expected to work with off-the-self OpenTelemetry Collector deployments.

## Usage

```swift

import NautilusTelemetry

InstrumentationSystem.bootstrap(reporter: ExampleReporter())

	func example() {
		let tracer = InstrumentationSystem.tracer
		tracer.withSpan(name: #function) {
			self.doWork()
		}
	}

```

## Contributing
Pull requests are welcome. Please install [swiftformat](https://github.com/nicklockwood/SwiftFormat) and run `swiftformat .` manually before submitting a PR. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.


## License
[MIT](https://choosealicense.com/licenses/mit/)
