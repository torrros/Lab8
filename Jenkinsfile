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
                    // Створення інфраструктури без ручного втручання [cite: 34, 56]
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('3. Dynamic Inventory') {
            steps {
                dir("${TF_HOME}") {
                    // Перевірка генерації inventory.ini [cite: 25, 35]
                    sh 'ls -l ../ansible/inventory.ini'
                }
            }
        }

        stage('4. Ansible Deployment') {
            steps {
                dir("${ANSIBLE_HOME}") {
                    // КРИТИЧНО: Очікування SSH перед конфігурацією 
                    sh 'ansible all -i inventory.ini -m wait_for_connection -a "timeout=300"'
                    
                    // Паралельний запуск конфігурації обох вузлів 
                    parallel(
                        "App Node": {
                            sh 'ansible-playbook -i inventory.ini playbook_app.yml'
                        },
                        "Monitor Node": {
                            sh 'ansible-playbook -i inventory.ini playbook_monitor.yml'
                        }
                    )
                }
            }
        }

        stage('5. Smoke Test') {
            steps {
                dir("${TF_HOME}") {
                    script {
                        // Отримання IP через outputs для перевірки доступності [cite: 25, 37]
                        def appIp = sh(script: "terraform output -raw app_node_ip", returnStdout: true).trim()
                        def monitorIp = sh(script: "terraform output -raw monitor_node_ip", returnStdout: true).trim()

                        // Перевірка веб-інтерфейсів (порт 80, 9090, 3000) [cite: 23, 24, 37]
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
            echo 'Пайплайн завершено.'
        }
        failure {
            echo 'Помилка розгортання. Перевірте логі Terraform або Ansible.'
        }
    }
}
