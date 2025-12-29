pipeline {
	agent {
		node {
			label "fernando-helsinki-01"
		}
	}

	stages {
		stage('Debug tests') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build test -Djson=true'
			}
		}
		stage('ReleaseSafe tests') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build test -Djson=true -Doptimize=ReleaseSafe'
			}
		}
		stage('ReleaseFast tests') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build test -Djson=true -Doptimize=ReleaseFast'
			}
		}
		stage('ReleaseSmall tests') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build test -Djson=true -Doptimize=ReleaseSmall'
			}
		}
		stage('Build binary with JSON flag') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build -Djson=true -Doptimize=ReleaseSmall'
			}
		}
		stage('Build ReleaseFast') {
			steps {
				sh 'docker run -v $PWD:/app denisgolius/zig:0.15.2 build test -Djson=true -Doptimize=ReleaseFast'
			}
		}
		stage('Install') {
			when { branch 'develop' }
			steps {
				sh 'cp ./zig-out/bin/thp /var/bin/thp'
			}
		}
	}
}

