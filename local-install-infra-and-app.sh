echo "🛺🛺🛺 install infrastructure ..."
cd dailyfeed-insfrastructure
source install-local.sh
cd ..
echo ""


echo "🛺🛺🛺 install app ..."
cd dailyfeed-app-helm
source install-local.sh
cd ..
echo ""

