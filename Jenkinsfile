pipeline {
    agent any
    options {
    skipDefaultCheckout(true)
    }
    environment {
        JAVA_HOME = 'C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.12.8-hotspot'
        NODE_HOME = 'C:\\Program Files\\nodejs'
        PATH = "${JAVA_HOME}\\bin;${NODE_HOME};${env.PATH}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('1. Verify Environment') {
            steps {
                bat '''
                echo ===== JAVA =====
                echo %JAVA_HOME%
                java -version

                echo ===== MAVEN =====
                mvn -version

                echo ===== NODE =====
                echo NODE_HOME=%NODE_HOME%
                where node
                node -v

                echo ===== NPM =====
                where npm
                npm -v
                '''
            }
        }

        stage('2. Verify Environment') {
            steps {
                echo '===== VERIFY ENVIRONMENT ====='

                bat '''
                echo ===== JAVA_HOME =====
                echo %JAVA_HOME%
        
                echo ===== JAVA =====
                java -version
        
                echo ===== MAVEN =====
                mvn -version
        
                echo ===== NODE =====
                node -v
        
                echo ===== NPM =====
                npm -v
                '''
            }
        }

        stage('3. Fetch Java 17 JRE') {
            steps {
                echo '===== FETCH APPLICATION JRE ====='

                powershell '''
                & "$env:WORKSPACE\\build\\fetch-jre.ps1"

                if ($LASTEXITCODE -ne 0) {
                    exit $LASTEXITCODE
                }
                '''
            }
        }

        stage('4. Install Playwright Chromium') {
            steps {
                echo '===== INSTALL PLAYWRIGHT CHROMIUM ====='

                powershell '''
                & "$env:WORKSPACE\\build\\install-playwright.ps1"

                if ($LASTEXITCODE -ne 0) {
                    exit $LASTEXITCODE
                }
                '''
            }
        }

        stage('5. Build Backend') {
            steps {
                echo '===== BUILD BACKEND ====='

                bat '''
                mvn -f backend\\pom.xml clean package -DskipTests -Dmaven.test.skip=true

                if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
                '''
            }
        }

        stage('6. Build Mock Server') {
            steps {
                echo '===== BUILD MOCK SERVER ====='

                bat '''
                mvn -f mock-naukri\\pom.xml clean package -DskipTests -Dmaven.test.skip=true

                if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
                '''
            }
        }

        stage('7. Build Frontend') {
            steps {
                echo '===== BUILD FRONTEND ====='

                powershell '''
                & "$env:WORKSPACE\\build\\phases\\build-frontend.ps1"

                if ($LASTEXITCODE -ne 0) {
                    exit $LASTEXITCODE
                }
                '''
            }
        }

        stage('7b. SonarQube Analysis') {
    steps {
        script {
            def scannerHome = tool 'SonarScanner'

            withCredentials([
                string(
                    credentialsId: 'sonarcloud-token',
                    variable: 'SONAR_TOKEN'
                )
            ]) {
                bat """
                "${scannerHome}\\bin\\sonar-scanner.bat" ^
                  -Dsonar.projectKey=naukri ^
                  -Dsonar.organization=vinayproj ^
                  -Dsonar.sources=backend/src,frontend/src,electron ^
                  -Dsonar.exclusions=**/node_modules/**,**/target/**,**/dist/** ^
                  -Dsonar.token=%SONAR_TOKEN%
                """
            }
        }
    }
        }

        stage('8. Build Electron Application') {
            steps {
                echo '===== BUILD ELECTRON APPLICATION ====='

                powershell '''
                & "$env:WORKSPACE\\build\\phases\\build-electron.ps1" -Variant Ship

                if ($LASTEXITCODE -ne 0) {
                    exit $LASTEXITCODE
                }
                '''
            }
        }

        stage('9. Verify Artifacts') {
            steps {
                echo '===== VERIFY ARTIFACTS ====='

                powershell '''
                $dist = "$env:WORKSPACE\\dist"

                if (-not (Test-Path $dist)) {
                    throw "dist directory does not exist"
                }

                Write-Host ""
                Write-Host "===== BUILD ARTIFACTS ====="

                Get-ChildItem $dist -Recurse -File |
                    Select-Object FullName, Length

                $exeFiles = Get-ChildItem $dist -Recurse -Filter "*.exe"

                if ($exeFiles.Count -eq 0) {
                    throw "No EXE artifacts found"
                }

                Write-Host ""
                Write-Host "===== EXE ARTIFACTS FOUND ====="

                foreach ($exe in $exeFiles) {
                    Write-Host $exe.FullName
                }

                Write-Host ""
                Write-Host "Artifact verification SUCCESS"
                '''
            }
        }

        stage('10. Archive Artifacts') {
            steps {
                echo '===== ARCHIVING ARTIFACTS ====='

                archiveArtifacts artifacts: 'dist/**/*.exe',
                                  fingerprint: true
            }
        }

        stage('11. Upload to Azure Blob Storage') {
            steps {
                echo '===== UPLOADING TO AZURE BLOB STORAGE ====='

                azureUpload(
                    containerName: 'naukri',
                    storageType: 'blobstorage',
                    filesPath: 'dist/**/*.exe',
                    storageCredentialId: 'azure-storage-cred'
                )
            }
        }

        stage('Ansible WinRM Test') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'windows-vm-credentials',
                        usernameVariable: 'VM_USERNAME',
                        passwordVariable: 'VM_PASSWORD'
                    )
                ]) {

                    powershell '''
                        $workspace = $env:WORKSPACE

                        Write-Host "Jenkins workspace:"
                        Write-Host $workspace

                        # Convert Windows path to WSL path
                        $wslWorkspace = wsl -d Debian wslpath -a "$workspace"

                        Write-Host "WSL workspace:"
                        Write-Host $wslWorkspace

                        $env:ANSIBLE_VM_USERNAME = $env:VM_USERNAME
                        $env:ANSIBLE_VM_PASSWORD = $env:VM_PASSWORD

                        wsl -d Debian bash -c "source /home/ajay/ansible-venv/bin/activate && cd '$wslWorkspace' && ansible windows -i inventory.ini -m ansible.windows.win_ping -e `"ansible_user=$ANSIBLE_VM_USERNAME`" -e `"ansible_password=$ANSIBLE_VM_PASSWORD`""
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '''
            ========================================
            NAUKRI CI BUILD SUCCESS
            ========================================
            Artifacts successfully generated.
            ========================================
            '''
        }

        failure {
            echo '''
            ========================================
            NAUKRI CI BUILD FAILED
            ========================================
            Check the first failed stage.
            ========================================
            '''
        }

        always {
            echo '===== Jenkins CI pipeline finished ====='
        }
    }
}
