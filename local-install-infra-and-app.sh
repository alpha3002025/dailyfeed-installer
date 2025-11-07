VERSION_ARG="$1"

echo "🛺🛺🛺 install infrastructure (Hybrid Mode: Docker Compose + Kubernetes) ..."
cd dailyfeed-infrastructure
# source install-local.sh
source install-local-hybrid.sh
cd ..
echo ""


if [ -n "$VERSION_ARG" ]; then
  echo "🛺🛺🛺 Installing with version: $VERSION_ARG"
else
  echo "🛺🛺🛺 Installing without version argument"
fi
echo ""

echo "🛺🛺🛺 install app ..."
cd dailyfeed-app-helm
if [ -n "$VERSION_ARG" ]; then
  source install-local.sh "$VERSION_ARG"
else
  source install-local.sh
fi
cd ..
echo ""