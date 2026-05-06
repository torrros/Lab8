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
                    // Використовуємо vm-pub-key для передачі публічного ключа в Terraform
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

        stage('4. Configuration & Deployment') {
            steps {
                // Використовуємо lab7 для автентифікації Ansible через SSH Agent 
                sshagent(['lab7']) {
                    dir("${TF_HOME}") {
                        // Очікування SS
                        sh "ansible all -i ${ANSIBLE_HOME}/inventory.ini -m wait_for_connection -a 'timeout=300'"
                        
                        // Паралельне розгортання
                        parallel(
                            "App Node": {
                                sh "ansible-playbook -i ${ANSIBLE_HOME}/inventory.ini ${ANSIBLE_HOME}/playbook_app.yml"
                            },
                            "Monitor Node": {
                                sh "ansible-playbook -i ${ANSIBLE_HOME}/inventory.ini ${ANSIBLE_HOME}/playbook_monitor.yml"
                            }
                        )
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

                        sh "curl -s --head http://${appIp}:80 | grep '200 OK'"
                        sh "curl -s --head http://${monitorIp}:9090 | grep '200 OK'"
                        sh "curl -s --head http://${monitorIp}:3000 | grep '200 OK'"
                    }
                }
            }
        }
    }

    post {
        always {
            dir("${TF_HOME}") {
                withCredentials([string(credentialsId: 'vm-pub-key', variable: 'PUBLIC_KEY')]) {
                    sh "terraform destroy -auto-approve -var='ssh_public_key=${PUBLIC_KEY}'"
                }
            }
            echo 'Пайплайн завершено.'
        }
    }
}
