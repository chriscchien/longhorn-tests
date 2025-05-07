create_appco_secret(){
    set +x
    kubectl -n default create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username="${APPCO_USERNAME}" --docker-password="${APPCO_PASSWORD}"
    kubectl -n longhorn-system create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username="${APPCO_USERNAME}" --docker-password="${APPCO_PASSWORD}"
    set +x

    kubectl patch serviceaccount default --type='merge' -p '{"imagePullSecrets":[{"name":"application-collection"}]}' -n default
    kubectl patch serviceaccount default --type='merge' -p '{"imagePullSecrets":[{"name":"application-collection"}]}' -n longhorn-system    
}