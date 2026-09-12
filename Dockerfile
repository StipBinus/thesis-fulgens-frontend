# Isolated Flutter + Android build environment.
# Matches local SDK: Flutter 3.29.3 / Dart 3.7.2
FROM ghcr.io/cirruslabs/flutter:3.29.3

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true

WORKDIR /app

# Pre-fetch deps first for better layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --no-example || flutter pub get

# Copy the rest (compose will mount repo over this at runtime)
COPY . ./

# Pre-warm Android artifacts + accept licenses
RUN flutter precache --android --no-web --no-ios --no-linux --no-windows --no-macos --no-fuchsia || true
RUN yes | flutter doctor --android-licenses || true
RUN flutter doctor

CMD ["flutter", "--version"]
