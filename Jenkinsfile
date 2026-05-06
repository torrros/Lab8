pipeline {
    agent any

    environment {
        TF_HOME = "${WORKSPACE}/terraform"
        ANSIBLE_HOME = "${WORKSPACE}/ansible"
    }

    stages {
        stage('1. Checkout') {
            steps {
                // Клонування репозиторію з кодом [cite: 33]
                checkout scm
            }
        }

        stage('2. Terraform Apply') {
            steps {
                dir("${TF_HOME}") {
                    sh 'terraform init'
		    script {
			def pubKey = readFile("id_rsa.pub").trim()
			sh "terraform apply -auto-approve -var='ssh_public_key=${pubKey}'"
		    }
		}
	    }
	}		
        stage('3. Dynamic Inventory') {
            steps {
                dir("${TF_HOME}") {
                    // Перевірка наявності згенерованого inventory.ini [cite: 25, 35]
                    sh 'ls -l inventory.ini'
                }
            }
        }

        stage('4. Wait for SSH') {
            steps {
                dir("${TF_HOME}") {
                    // Обов'язкове очікування доступності ВМ перед конфігурацією 
                    sh 'ansible all -i inventory.ini -m wait_for_connection -a "timeout=300"'
                }
            }
        }

        stage('5. Ansible Deployment') {
            // Паралельний запуск конфігурації обох серверів 
            parallel {
                stage('Configure App Node') {
                    steps {
                        dir("${TF_HOME}") {
                            sh "ansible-playbook -i inventory.ini ${ANSIBLE_HOME}/playbook_app.yml"
                        }
                    }
                }
                stage('Configure Monitor Node') {
                    steps {
                        dir("${TF_HOME}") {
                            sh "ansible-playbook -i inventory.ini ${ANSIBLE_HOME}/playbook_monitor.yml"
                        }
                    }
                }
            }
        }

        stage('6. Smoke Test') {
            steps {
                dir("${TF_HOME}") {
                    script {
                        // Перевірка доступності веб-інтерфейсів через curl [cite: 37]
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
                 sh 'terraform destroy -auto-approve'
        }
            echo 'Пайплайн завершено.'
        }
    }
    post {
        always {
            echo 'Пайплайн завершено.'
        }
        failure {
            echo 'Розгортання не вдалося. Перевірте конфігурацію IaC або сценарії Ansible.'
        }
    }
}

