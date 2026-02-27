// seed-job.groovy — Auto-creates the MatlabToCpp pipeline job
//
// This is loaded by Jenkins Configuration as Code on first boot.
// It creates a Pipeline job that pulls the Jenkinsfile from GitHub.

pipelineJob('MatlabToCpp') {
    description('''
        <h3>MATLAB-to-C++ Algorithm Delivery Pipeline</h3>
        <p>Automatically tests MATLAB algorithms, generates C++ via MATLAB Coder,
        verifies equivalence, and publishes Conan packages to Nexus.</p>
        <p><a href="https://github.com/blake-perkins/MatlabToCpp">GitHub Repository</a></p>
    ''')

    // Keep last 30 builds
    logRotator {
        numToKeep(30)
    }

    // Parameters (matching Jenkinsfile)
    parameters {
        booleanParam('FORCE_ALL', false, 'Build all algorithms, not just changed ones')
        stringParam('FORCE_ALGO', '', 'Force build specific algorithm(s) (comma-separated)')
    }

    // Pull pipeline definition from GitHub
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/blake-perkins/MatlabToCpp.git')
                    }
                    branches('*/main')
                }
            }
            scriptPath('Jenkinsfile')
            lightweight(true)
        }
    }

    // Trigger on push (via webhook or polling)
    triggers {
        // Poll SCM every 5 minutes as fallback if webhook not configured
        scm('H/5 * * * *')
    }
}
