# localTest/

Este directorio contiene un Dockerfile para **compilar** y correr **tests unitarios Go** del repo sin depender de librerías externas.

## Requisitos

- Docker (o Podman compatible con Dockerfile)

## Correr tests (rápido)

```bash
docker build -f localTest/Dockerfile --target test .
```

## Correr tests con race detector

```bash
docker build -f localTest/Dockerfile --target race .
```

> Nota: `-race` suele ser más lento, pero ayuda a detectar data races.

## Compilar el binario del server (export a carpeta local)

```bash
mkdir -p out

docker build -f localTest/Dockerfile --target build -o out .

# recomendado (mismo resultado, output más limpio):
docker build -f localTest/Dockerfile --target artifacts -o out .

# binario generado:
#   out/kwkhtmltopdf_server
```

## Prueba de integración (wkhtmltopdf real)

Hace un build que instala `wkhtmltopdf/wkhtmltoimage`, levanta el server y valida:

- `/status`
- conversión real en `/pdf` (magic `%PDF`)
- conversión real en `/image` (firma PNG o JPEG)
- `/metrics`

```bash
docker build -f localTest/Dockerfile --target integration .
```

## Smoke test del runtime (docker run)

Esto prueba el contenedor final (target `runtime`): build + `docker run` + requests reales y validación de `/metrics`.

```bash
bash localTest/runtime_smoke_test.sh
```

## Qué cubre / qué no cubre

- No cubre: tests de integración que requieren ejecución real del server (eso lo cubre el target `integration`).
