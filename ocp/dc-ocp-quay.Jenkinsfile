node('maven') {
    stage ('git clone') {
        sh "git config --global http.sslVerify false"
        withCredentials([usernamePassword(credentialsId: 'customs-gitlab-credential', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            sh "git clone https://\${USERNAME}:\${PASSWORD}@gitlab.customs.go.id/ngurah.angga/penugasan-service.git source "
        }
    }
    stage ('App Build') {
        dir("source") {
            sh "git fetch"
            sh "git switch develop"
            //sh "mvn clean package -Dmaven.repo.local=/tmp/maven/ -Dmaven.test.skip=true"
            sh "mvn clean package -Dmaven.test.skip=true"
        }
    }
    stage ('App Push') {
        dir("source") {
            sh "mkdir -p build-folder/target/ build-folder/apps/ "
            sh "cp ocp.Dockerfile build-folder/Dockerfile"
            sh "cp target/*.jar build-folder/target/"

            def tag = sh(returnStdout: true, script: "git rev-parse --short=8 HEAD").trim();
            
            sh "cat build-folder/Dockerfile | oc new-build -D - --name penugasan-service || true"
            sh "oc start-build penugasan-service --from-dir=build-folder/. --follow --wait "
            //sleep(time:600,unit:"SECONDS")
            //NEW SECTION BELOW//
            sh "oc tag cicd3/penugasan-service:latest cehrisservice/penugasan-service:${tag} "
			
			sh "oc registry login"
		
			//QUAY FORMAT <registry>/djbc/<namespace>_<deployment_name>
			withCredentials([
			    usernamePassword(credentialsId: 'quay-drc-credential', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')
			    ]){
                   sh "skopeo copy docker://default-route-openshift-image-registry.apps.proddc.customs.go.id/cehrisservice/penugasan-service:${tag} docker://quay-registry.apps.proddc.customs.go.id/djbc/cehrisservice_penugasan-service:${tag} --dest-creds \${USERNAME}:\${PASSWORD} --dest-tls-verify=false"
                   sh "oc tag cicd3/penugasan-service:latest cehrisservice/penugasan-service:latest "
                   sh "skopeo copy docker://default-route-openshift-image-registry.apps.proddc.customs.go.id/cehrisservice/penugasan-service:latest docker://quay-registry.apps.proddc.customs.go.id/djbc/cehrisservice_penugasan-service:latest --dest-creds \${USERNAME}:\${PASSWORD} --dest-tls-verify=false"
               }
        }
    }
    stage ('App Deploy') {
        dir("source") {
		    //CHANGE INTO QUAY, COPY FROM ABOVE
            sh "sed 's,\\\$REGISTRY/\\\$HARBOR_NAMESPACE/\\\$APP_NAME:\\\$BUILD_NUMBER,quay-registry.apps.proddc.customs.go.id/djbc/cehrisservice_penugasan-service:latest,g' kubernetes_dev-quay.yaml > kubernetes-ocp-quay.yaml"
            sh "oc apply -f kubernetes-ocp-quay.yaml -n cehrisservice"
            sh "oc set triggers deployment/penugasan-service --from-image=quay-registry.apps.proddc.customs.go.id/djbc/cehrisservice_penugasan-service:latest -c penugasan-service -n cehrisservice || true "
        }
    }
}
