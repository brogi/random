                   steps {
                        script {
                            def CONSUMER_ID = sh(script: """ curl -s -H \"apiKey: ${EKS_ADMIN_KEY}\" \"${KONG_URL_EKS}/consumers/elis_jwt\" | jq ".id" | tr -d "\n" """, returnStdout: true)
                            println "CONSUMER_ID: ${CONSUMER_ID}"
                            def JWT_ID = sh(script: """ curl -s -H \"apiKey: ${EKS_ADMIN_KEY}\" \"${KONG_URL_EKS}/consumers/${CONSUMER_ID}/jwt\" | jq '.data[].\"id\"'  | tr -d "\n" """, returnStdout: true)
                            println "JWT_ID: ${JWT_ID}"
                            sh(script: """ curl -X DELETE -s -H \"apiKey: ${EKS_ADMIN_KEY}\" \"${KONG_URL_EKS}/consumers/${CONSUMER_ID}/jwt/${JWT_ID}\" """)
