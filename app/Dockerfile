FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /out/hello .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/hello /hello
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/hello"]
