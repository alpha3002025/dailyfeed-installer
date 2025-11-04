VERSION_ARG="$1"

echo "🛺🛺🛺 install infrastructure (dev profile)..."
cd dailyfeed-infrastructure
source install-dev.sh
cd ..
echo ""


if [ -n "$VERSION_ARG" ]; then
  echo "🛺🛺🛺 Installing application with version: $VERSION_ARG"
else
  echo "🛺🛺🛺 Installing application without version argument"
fi
echo ""

echo "🛺🛺🛺 install app (dev profile)..."
cd dailyfeed-app-helm
if [ -n "$VERSION_ARG" ]; then
  source install-dev.sh "$VERSION_ARG"
else
  source install-dev.sh
fi
cd ..
echo ""
