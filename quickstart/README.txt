helm repo add stakater https://stakater.github.io/stakater-charts
helm repo add cert-manager https://charts.jetstack.io
helm repo add mongodb https://mongodb.github.io/helm-charts

helm repo update

helm install --create-namespace --namespace reloader --values reloader-values.yaml reloader stakater/reloader
helm install --create-namespace --namespace mongodb-kubernetes-operator --values mongodb-operator-values.yaml mongodb-kubernetes-operator mongodb/mongodb-kubernetes
helm install --create-namespace --namespace cert-manager --values certmanager-values.yaml cert-manager cert-manager/cert-manager
