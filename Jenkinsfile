pipeline {
	agent any

	stages {
		stage('Build binary with JSON flag') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.13.0 build -Djson=true -Doptimize=ReleaseSmall'
			}
		}
		stage('Move binary') {
			steps {
				sh 'mv ./zig-out/bin/thp /var/bin/thp-zig'
			}
		}
	}
}


