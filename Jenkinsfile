pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
    }

    environment {
        JAVA_HOME = 'C:\\Program Files\\Microsoft\\jdk-17.0.20.8-hotspot'
        NODE_HOME = 'C:\\Program Files\\nodejs'
        PATH = "${JAVA_HOME}\\bin;${NODE_HOME};${env.PATH}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo '===== CHECKOUT FROM GIT ====='
                checkout scm
            }
        }

        stage('1. Verify Environment') {
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
                echo NODE_HOME=%NODE_HOME%
                where node
                node -v

                echo ===== NPM =====
                where npm
                npm -v
                '''
            }
        }

        stage('2. Fetch Java 17 JRE') {
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

        stage('4. Build Backend') {
            steps {
                echo '===== BUILD BACKEND ====='

                bat '''
                mvn -f backend\\pom.xml clean package -DskipTests -Dmaven.test.skip=true

                if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
                '''
            }
        }

        stage('5. Build Mock Server') {
            steps {
                echo '===== BUILD MOCK SERVER ====='

                bat '''
                mvn -f mock-naukri\\pom.xml clean package -DskipTests -Dmaven.test.skip=true

                if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
                '''
            }
        }
        stage('7. SonarQube Analysis') {
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
        
        stage('6. Build Frontend') {
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

                archiveArtifacts(
                    artifacts: 'dist/**/*.exe',
                    fingerprint: true
                )
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
        stage('12. Verify Ansible Inventory') {
            steps {
                echo '===== VERIFY ANSIBLE INVENTORY ====='

                powershell '''
                $inventory = Join-Path $env:WORKSPACE "inventory.ini"

                if (-not (Test-Path $inventory)) {
                    throw "inventory.ini was not found in the Git workspace: $inventory"
                }

                Write-Host "===== INVENTORY FOUND ====="
                Write-Host $inventory

                Get-Content $inventory
                '''
            }
        }
		
		stage('13. Ansible WinRM Test') {
			steps {
				echo '===== ANSIBLE WINDOWS VM TEST ====='

				withCredentials([
					usernamePassword(
						credentialsId: 'windows-vm-credentials',
						usernameVariable: 'VM_USERNAME',
						passwordVariable: 'VM_PASSWORD'
					)
				]) {

					powershell '''
						$ErrorActionPreference = "Stop"

						Write-Host "===== JENKINS WORKSPACE ====="
						Write-Host $env:WORKSPACE

						$inventory = Join-Path $env:WORKSPACE "inventory.ini"

						if (-not (Test-Path $inventory)) {
							throw "inventory.ini not found: $inventory"
						}

						Write-Host "Inventory:"
						Write-Host $inventory

						Write-Host "===== CONVERT WORKSPACE TO WSL ====="

						$wslWorkspace = $env:WORKSPACE.Replace('\\','/')
						$wslWorkspace = $wslWorkspace -replace '^C:', '/mnt/c'

						Write-Host "WSL Workspace:"
						Write-Host $wslWorkspace

						Write-Host "===== CHECK WSL ====="

						wsl -d Debian -- echo "WSL Debian works"

						if ($LASTEXITCODE -ne 0) {
							throw "WSL Debian is not available"
						}

						Write-Host "===== CHECK ANSIBLE ====="

						wsl -d Debian bash -c "source /home/ajay/ansible-venv/bin/activate && ansible --version"

						if ($LASTEXITCODE -ne 0) {
							throw "Ansible is not available"
						}

						Write-Host "===== CHECK INVENTORY ====="

						wsl -d Debian bash -c "ls -l '$wslWorkspace/inventory.ini'"

						if ($LASTEXITCODE -ne 0) {
							throw "inventory.ini cannot be accessed from WSL"
						}

						Write-Host "===== RUN ANSIBLE WIN_PING ====="

						$env:ANSIBLE_VM_USERNAME = $env:VM_USERNAME
						$env:ANSIBLE_VM_PASSWORD = $env:VM_PASSWORD

						wsl -d Debian bash -c "source /home/ajay/ansible-venv/bin/activate && cd '$wslWorkspace' && ansible windows -i inventory.ini -m ansible.windows.win_ping -e `"ansible_user=$env:ANSIBLE_VM_USERNAME`" -e `"ansible_password=$env:ANSIBLE_VM_PASSWORD`""

						if ($LASTEXITCODE -ne 0) {
							throw "Ansible WinRM connection failed"
						}

						Write-Host "===== ANSIBLE WIN_PING SUCCESS ====="
					'''
				}
			}
		}
		stage('14. Deploy with Ansible') {
			steps {
					echo '===== DEPLOYING TO WINDOWS VM ====='
					 withCredentials([
						usernamePassword(
							credentialsId: 'windows-vm-credentials',
							usernameVariable: 'VM_USERNAME',
							passwordVariable: 'VM_PASSWORD'
						)
					]) {

					powershell '''
					$artifact = Get-ChildItem "$env:WORKSPACE\\dist" -Filter "*.exe" |
								 Select-Object -First 1

					if (-not $artifact) {
						throw "No EXE found in dist"
					}

					Write-Host "Artifact: $($artifact.FullName)"

					Write-Host "===== COPY EXE TO WSL ====="
					wsl -d Debian bash -c "mkdir -p /home/ajay/naukri/artifacts"

					wsl -d Debian bash -c "cp /mnt/d/ABC/4project/Naukri/dist/$($artifact.Name) /home/ajay/naukri/artifacts/"

					 Write-Host "===== RUN ANSIBLE PLAYBOOK ====="
					wsl -d Debian bash -c "source /home/ajay/ansible-venv/bin/activate && cd /home/ajay/naukri && ansible-playbook -i inventory.ini deploy.yml -e artifact_path=/home/ajay/naukri/artifacts/$($artifact.Name) -e ansible_user=$env:ANSIBLE_VM_USERNAME -e ansible_password=$env:ANSIBLE_VM_PASSWORD"

					if ($LASTEXITCODE -ne 0) {
						throw "Ansible deployment failed"
					}
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
            Ansible WinRM connection successful.
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
