pipeline {
	agent any

	stages {
		stage('Build binary with JSON flag') {
			agent {
				docker {
					reuseNode true
					image 'eloitor/zig:0.13.0'
				}
			}
			steps {
				sh 'zig build -Djson=true -Doptimize=ReleaseSmall'
			}
		}
		stage('Move binary') {
			steps {
				sh 'mv ./zig-out/bin/thp /var/bin/thp-zig'
			}
		}
	}
}


