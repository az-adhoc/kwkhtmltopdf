# Release

## Client Build and upload

```sh
go build -o ./kwkhtmltopdf client/go/pdf/kwkhtmltopdf_client.go 
go build -o ./kwkhtmltoimage client/go/image/kwkhtmltoimage_client.go

gh auth login

# 2) Crear y subir tag
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0

# 3) Crear release y subir binarios como assets
gh release create v0.1.0 \
  ./client/go/kwkhtmltoimage \
  ./client/go/kwkhtmltopdf \
  --title "v0.1.0" \
  --notes "Binaries Go de kwkhtmltoimage y kwkhtmltopdf"
```

## Server Build and upload

```sh
BUILD_DATE=$(/bin/date -u "+%Y.%m.%d").1
docker build --no-cache -f localTest/Dockerfile --target runtime  -t adhoc/ops-tools:kwkhtmltopdf-${BUILD_DATE} .
docker push adhoc/ops-tools:kwkhtmltopdf-$BUILD_DATE
```
