pipeline {
    agent any

    environment {
        TF_HOME = "${WORKSPACE}/terraform"
        ANSIBLE_HOME = "${WORKSPACE}/ansible"
    }

    stages {
        stage('1. Checkout') {
            steps {
                // Клонування репозиторію [cite: 33]
                checkout scm
            }
        }

        stage('2. Terraform Apply') {
            steps {
                dir("${TF_HOME}") {
                    sh 'terraform init'
                    // Створення інфраструктури [cite: 34, 56]
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('3. Dynamic Inventory') {
            steps {
                dir("${TF_HOME}") {
                    // Генерація inventory.ini на основі виводу Terraform [cite: 25, 35]
                    // Ми використовуємо local_file, який ви вже описали в main.tf, 
                    // тому просто переконуємося, що файл створено.
                    sh 'ls -l ../ansible/inventory.ini'
                }
            }
        }

        stage('4. Ansible Deployment') {
            parallel {
		stage ('App Node'){
                    steps {                        
                        sh 'ansible-playbook -i ansible/inventory.ini ansible/playbook_app.yml'
                    }
		}
                stage ('Monitor Node') {
		    steps {	
                        sh 'ansible-playbook -i inventory.ini playbook_monitor.yml'
                    }
                )
             }
         }

        stage('5. Smoke Test') {
            steps {
                dir("${TF_HOME}") {
                    script {
                        // Отримуємо IP з terraform outputs для тестів 
                        def appIp = sh(script: "terraform output -raw app_node_ip", returnStdout: true).trim()
                        def monitorIp = sh(script: "terraform output -raw monitor_node_ip", returnStdout: true).trim()
                        
                        // Перевірка доступності веб-інтерфейсів 
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
            // Опційно: terraform destroy для економії ресурсів 
            echo 'Пайплайн завершено.'
        }
        failure {
            echo 'Помилка при виконанні пайплайну. Перевірте логи.'
        }
    }
}
