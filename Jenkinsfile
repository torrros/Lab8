pipeline {
    agent any

    environment {
        TF_HOME = "${WORKSPACE}/terraform"
        ANSIBLE_HOME = "${WORKSPACE}/ansible"
    }

    stages {
        stage('1. Checkout') {
            steps {
                checkout scm // [cite: 33]
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
                // Перевірка генерації inventory.ini [cite: 35]
                sh "ls -l ${ANSIBLE_HOME}/inventory.ini"
            }
        }

        stage('4. Wait for SSH') {
            steps {
                sshagent(['lab7']) {
                    dir("${TF_HOME}") {
                        // Очікування доступності вузлів перед конфігурацією 
                        sh "ansible all -i ${ANSIBLE_HOME}/inventory.ini -m wait_for_connection -a 'timeout=300'"
                    }
                }
            }
        }

        stage('5. Ansible Deployment') {
            // Паралельний запуск конфігурації обох серверів 
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
                            dir("${TF_HOME}") {
                                sh "ansible-playbook -i ${ANSIBLE_HOME}/inventory.ini ${ANSIBLE_HOME}/playbook_monitor.yml"
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
                        // Перевірка доступності веб-інтерфейсів [cite: 37]
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
                // Стійкість та очищення ресурсів 
                withCredentials([string(credentialsId: 'vm-pub-key', variable: 'PUBLIC_KEY')]) {
                    sh "terraform destroy -auto-approve -var='ssh_public_key=${PUBLIC_KEY}'"
                }
            }
            echo 'Пайплайн завершено.'
        }
        failure {
            echo 'Розгортання не вдалося. Перевірте конфігурацію IaC або сценарії Ansible.'
        }
    }
}
