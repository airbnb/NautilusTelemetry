From:

https://jessitron.com/2021/08/11/run-an-opentelemetry-collector-locally-in-docker/

See also: https://opentelemetry.io/docs/collector/configuration/

Run this:

`docker run \
-v "${PWD}/otel-local-config.yaml":/otel-local-config.yaml \
-p 4318:4318 \
otel/opentelemetry-collector \
--config otel-local-config.yaml;`

