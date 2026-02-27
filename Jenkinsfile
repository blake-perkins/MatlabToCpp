/**
 * MatlabToCpp Pipeline
 *
 * Automated MATLAB-to-C++ algorithm delivery pipeline.
 * All logic is delegated to shell scripts in scripts/ for portability.
 *
 * Stages:
 *   1. Detect Changes    — which algorithms were modified?
 *   2. MATLAB Tests      — validate MATLAB code against test vectors
 *   3. Code Generation   — run MATLAB Coder to produce C++
 *   4. C++ Build         — CMake configure + build
 *   5. C++ Tests         — Google Test against same test vectors
 *   6. Equivalence Check — compare MATLAB vs C++ outputs
 *   7. Version Bump      — semantic versioning from commit messages
 *   8. Generate Reports  — diffs, release notes, API comparison
 *   9. Publish to Nexus  — Conan package upload (main branch only)
 *  10. Notify            — email algorithm owners and C++ consumers
 */

pipeline {
    agent { label 'matlab-linux' }

    environment {
        NEXUS_URL    = credentials('nexus-conan-url')
        NEXUS_CREDS  = credentials('nexus-conan-creds')
        MATLAB_ROOT  = '/opt/MATLAB/R2024b'
        CONAN_HOME   = "${WORKSPACE}/.conan2"
    }

    parameters {
        booleanParam(
            name: 'FORCE_ALL',
            defaultValue: false,
            description: 'Build all algorithms, not just changed ones'
        )
        string(
            name: 'FORCE_ALGO',
            defaultValue: '',
            description: 'Force build specific algorithm(s) (comma-separated)'
        )
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    stages {
        // ---- Stage 1: Detect Changes ----
        stage('Detect Changes') {
            steps {
                script {
                    sh "bash scripts/detect_changes.sh '${env.GIT_PREVIOUS_SUCCESSFUL_COMMIT ?: 'HEAD~1'}'"

                    def changed = readFile('changed_algorithms.txt').trim()

                    if (params.FORCE_ALL) {
                        changed = sh(
                            script: "ls -d algorithms/*/ | xargs -n1 basename | tr '\\n' ' '",
                            returnStdout: true
                        ).trim().replace(' ', '\n')
                    }

                    if (params.FORCE_ALGO?.trim()) {
                        changed = params.FORCE_ALGO.trim().replace(',', '\n')
                    }

                    if (!changed) {
                        currentBuild.result = 'NOT_BUILT'
                        error('No algorithm changes detected. Skipping pipeline.')
                    }

                    env.CHANGED_ALGORITHMS = changed
                    echo "Algorithms to build: ${changed}"
                }
            }
        }

        // ---- Stage 2: MATLAB Tests ----
        stage('MATLAB Tests') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["MATLAB Test: ${algo}"] = {
                            sh "bash scripts/run_matlab_tests.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 3: Code Generation ----
        stage('Code Generation') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["Codegen: ${algo}"] = {
                            sh "bash scripts/run_codegen.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 4: C++ Build ----
        stage('C++ Build') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["Build: ${algo}"] = {
                            sh "bash scripts/build_cpp.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 5: C++ Tests ----
        stage('C++ Tests') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["C++ Test: ${algo}"] = {
                            sh "bash scripts/run_cpp_tests.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 6: Equivalence Check ----
        stage('Equivalence Check') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["Equivalence: ${algo}"] = {
                            sh "bash scripts/run_equivalence.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 7: Version Bump ----
        // Sequential — each algorithm's tag must be committed before the next
        stage('Version Bump') {
            when { branch 'main' }
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    algos.each { algo ->
                        sh "bash scripts/bump_version.sh ${algo}"
                    }
                }
            }
        }

        // ---- Stage 8: Generate Reports ----
        stage('Generate Reports') {
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    def stages = [:]
                    algos.each { algo ->
                        stages["Report: ${algo}"] = {
                            sh "bash scripts/generate_reports.sh ${algo}"
                        }
                    }
                    parallel stages
                }
            }
        }

        // ---- Stage 9: Publish to Nexus ----
        stage('Publish to Nexus') {
            when { branch 'main' }
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    algos.each { algo ->
                        sh "bash scripts/publish_conan.sh ${algo}"
                    }
                }
            }
        }

        // ---- Stage 10: Notify ----
        stage('Notify') {
            when { branch 'main' }
            steps {
                script {
                    def algos = env.CHANGED_ALGORITHMS.split('\n')
                    algos.each { algo ->
                        sh "bash scripts/notify.sh ${algo} success"
                    }
                }
            }
        }
    }

    post {
        failure {
            script {
                env.CHANGED_ALGORITHMS?.split('\n')?.each { algo ->
                    sh "bash scripts/notify.sh ${algo} failure || true"
                }
            }
        }
        always {
            // Archive all reports and test results
            archiveArtifacts artifacts: 'results/**/*', allowEmptyArchive: true

            // Publish JUnit test results
            junit allowEmptyResults: true,
                  testResults: 'results/**/cpp/*_results.xml'

            // Push version tags back to Git (main branch only)
            script {
                if (env.BRANCH_NAME == 'main') {
                    sh 'git push origin --tags 2>/dev/null || true'
                }
            }
        }
    }
}
