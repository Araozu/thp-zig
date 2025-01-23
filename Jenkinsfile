pipeline {
	agent {
		docker {
			reuseNode true
			image 'stagex/zig:0.13.0'
		}
	}
	stages {
		stage('Build binary with JSON flag') {
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


