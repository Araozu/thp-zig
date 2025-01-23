pipeline {
	agent any

	stages {
		stage('Build binary with JSON flag') {
			steps {
				sh 'docker run -v /home/fernando/services/jenkins/data/workspace/thp-zig:/app denisgolius/zig:0.13.0 build -Djson=true -Doptimize=ReleaseSmall'
			}
		}
		stage('Move binary') {
			steps {
				sh 'mv ./zig-out/bin/thp /var/bin/thp-zig'
			}
		}
	}
}


