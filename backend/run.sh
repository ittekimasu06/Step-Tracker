#!/usr/bin/env bash
# Starts the Steptrack Spring Boot backend for local development.
#
# Reads secrets from backend/.env (gitignored, not committed) if it exists.
# Copy .env.example to .env and fill in your real values the first time.
set -euo pipefail

# This script uses Git-Bash/MSYS path conventions (e.g. /c/Program Files/...),
# which don't exist under WSL. If your terminal's `bash` resolves to WSL's
# bash.exe (common on a stock Windows PATH - C:\Windows\System32\bash.exe is
# a WSL launcher, separate from Git Bash's) everything below fails with a
# confusing "JAVA_HOME environment variable is not defined correctly" error.
# Run this from an actual Git Bash shell instead - e.g. from PowerShell:
#   & "C:\Program Files\Git\bin\bash.exe" backend/run.sh
if uname -r 2>/dev/null | grep -qi microsoft; then
  echo "This is WSL, not Git Bash - the /c/... paths below won't resolve here." >&2
  echo "Run this from Git Bash instead, e.g. from PowerShell:" >&2
  echo '  & "C:\Program Files\Git\bin\bash.exe" backend/run.sh' >&2
  exit 1
fi

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

: "${SPRING_DATASOURCE_PASSWORD:?SPRING_DATASOURCE_PASSWORD is not set. Copy backend/.env.example to backend/.env and fill it in.}"
: "${JWT_SECRET:=dev-only-secret-change-me-in-production-minimum-256-bits-long}"
: "${GOOGLE_CLIENT_IDS:=}"
export SPRING_DATASOURCE_PASSWORD JWT_SECRET GOOGLE_CLIENT_IDS

# JDK 21 and 25 both work; JAVA_HOME is left alone if already set (e.g. by your shell profile).
if [ -z "${JAVA_HOME:-}" ]; then
  export JAVA_HOME="/c/Program Files/Java/jdk-25"
fi

# Maven isn't on PATH on this machine; fall back to the wrapper-installed copy.
# Edit MVN below if your Maven lives somewhere else.
if command -v mvn >/dev/null 2>&1; then
  MVN="mvn"
else
  MVN="/c/Users/ItteKuru/.m2/wrapper/dists/apache-maven-3.9.16-bin/5grr65jo27hi51sujmtcldfovl/apache-maven-3.9.16/bin/mvn"
fi

# Keeps the JVM's heap small enough to start reliably on this machine even
# under memory pressure. Override with BACKEND_JVM_ARGS if you need more.
JVM_ARGS="${BACKEND_JVM_ARGS:--Xmx384m -XX:MaxMetaspaceSize=192m}"

echo "Starting Steptrack backend (JAVA_HOME=$JAVA_HOME)..."
exec "$MVN" spring-boot:run -Dspring-boot.run.jvmArguments="$JVM_ARGS"
