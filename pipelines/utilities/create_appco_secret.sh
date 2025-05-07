create_appco_secret(){
    kubectl -n default create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username="${APPCO_USERNAME}" --docker-password="${APPCO_PASSWORD}"
    kubectl -n longhorn-system create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username="${APPCO_USERNAME}" --docker-password="${APPCO_PASSWORD}"
}