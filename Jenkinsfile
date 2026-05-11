pipeline {
    agent any

    environment {
        TF_HOME = "${WORKSPACE}/terraform"
        ANSIBLE_HOME = "${WORKSPACE}/ansible"
    }

    stages {
        stage('1. Checkout') {
            steps {
                checkout scm
            }
        }

        stage('2. Terraform Apply') {
            steps {
                dir("${TF_HOME}") {
                    sh 'terraform init'
                    // Використовуємо vm-pub-key для передачі в Terraform [cite: 34]
                    withCredentials([string(credentialsId: 'vm-pub-key', variable: 'PUBLIC_KEY')]) {
                        sh "terraform apply -auto-approve -var='ssh_public_key=${PUBLIC_KEY}'"
                    }
                }
            }
        }

        stage('3. Dynamic Inventory') {
            steps {
                sh "ls -l ${ANSIBLE_HOME}/inventory.ini"
            }
        }

        stage('4. Wait for SSH') {
            steps {
                sshagent(['lab7']) {
                    dir("${TF_HOME}") {
                        sh "ansible all -i ${ANSIBLE_HOME}/inventory.ini -m wait_for_connection -a 'timeout=300'"
                    }
                }
            }
        }

        stage('5. Ansible Deployment') {
            parallel {
                stage('Configure App Node') {
                    steps {
                        sshagent(['lab7']) {
                            dir("${TF_HOME}") {
                                sh "ansible-playbook -i ${ANSIBLE_HOME}/inventory.ini ${ANSIBLE_HOME}/playbook_app.yml"
                            }
                        }
                    }
                }
                stage('Configure Monitor Node') {
                    steps {
                        sshagent(['lab7']) {
                            dir("${ANSIBLE_HOME}") {
                                sh "ansible-playbook -i inventory.ini playbook_monitor.yml"
                            }
                        }
                    }
                }
            }
        }

        stage('6. Smoke Test') {
            steps {
                dir("${TF_HOME}") {
                    script {
                        def appIp = sh(script: "terraform output -raw app_node_ip", returnStdout: true).trim()
                        def monitorIp = sh(script: "terraform output -raw monitor_node_ip", returnStdout: true).trim()
                        sh "sleep 60"

			sh """
			    timeout 300 bash -c '
                            until curl -s http://${appIp}:80 > /dev/null; do
		                sleep 5
			    done 
			    '
			"""

                        sh """
                            timeout 300 bash -c '
                            until curl -s http://${monitorIp}:9090 > /dev/null; do
                                sleep 5
                            done
                            '
                        """

                        sh """
                            timeout 300 bash -c '
                            until curl -s http://${monitorIp}:3000 > /dev/null; do
                                sleep 5
                            done
                            '
                        """

                   }
                }
            }
        }
    }

    post {
        failure {
            dir("${TF_HOME}") {
                withCredentials([string(credentialsId: 'vm-pub-key', variable: 'PUBLIC_KEY')]) {
                    sh "terraform destroy -auto-approve -var='ssh_public_key=${PUBLIC_KEY}'"
                }
            }
        }
    }
}
