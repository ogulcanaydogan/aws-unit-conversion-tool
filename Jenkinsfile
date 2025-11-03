pipeline {
  agent {
    docker {
      image 'node:20-alpine'
      args '-u root:root'
    }
  }
  options {
    ansiColor('xterm')
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds()
  }
  parameters {
    booleanParam(name: 'RUN_FORMAT_CHECK', defaultValue: false, description: 'Run Prettier formatting checks (requires internet access).')
    booleanParam(name: 'DEPLOY_TO_S3', defaultValue: false, description: 'Sync the built site to the provided S3 bucket.')
    string(name: 'S3_BUCKET', defaultValue: '', description: 'Destination S3 bucket for deployment when enabled.')
    booleanParam(name: 'CREATE_CLOUDFRONT_INVALIDATION', defaultValue: false, description: 'Issue a CloudFront cache invalidation after deployment.')
    string(name: 'CLOUDFRONT_DISTRIBUTION_ID', defaultValue: '', description: 'CloudFront distribution ID used for cache invalidation when enabled.')
    string(name: 'AWS_CREDENTIALS_ID', defaultValue: '', description: 'Jenkins credentials ID granting AWS access for deployment steps.')
  }
  environment {
    BUILD_DIR = 'build'
    AWS_REGION = 'us-east-1'
  }
  stages {
    stage('Environment Info') {
      steps {
        sh '''
          set -eux
          node -v
          npm -v
          uname -a
        '''
      }
    }
    stage('Install Tooling') {
      steps {
        sh '''
          set -eux
          apk add --no-cache bash coreutils zip git terraform
        '''
        script {
          if (params.DEPLOY_TO_S3 || params.CREATE_CLOUDFRONT_INVALIDATION) {
            sh '''
              set -eux
              apk add --no-cache python3 py3-pip
              pip3 install --no-cache-dir awscli
            '''
          } else {
            echo 'Skipping AWS CLI installation because deployment steps are disabled.'
          }
        }
      }
    }
    stage('Install Dependencies') {
      steps {
        sh '''
          set -eux
          if [ -f package.json ]; then
            npm ci
          else
            echo "No package.json found, skipping dependency installation"
          fi
        '''
      }
    }
    stage('Format Check') {
      when {
        expression { return params.RUN_FORMAT_CHECK }
      }
      steps {
        sh '''
          set -eux
          npx --yes prettier@3.2.5 --check index.html assets/css/styles.css
        '''
      }
    }
    stage('Terraform Formatting') {
      when {
        expression { return fileExists('main.tf') }
      }
      steps {
        sh '''
          set -eux
          terraform fmt -check
        '''
      }
    }
    stage('Build Static Bundle') {
      steps {
        sh '''
          set -eux
          rm -rf "${BUILD_DIR}"
          mkdir -p "${BUILD_DIR}"
          cp index.html "${BUILD_DIR}/"
          if [ -d assets ]; then
            cp -R assets "${BUILD_DIR}/"
          fi
        '''
      }
    }
    stage('Package Artifact') {
      steps {
        sh '''
          set -eux
          rm -f site.zip
          cd "${BUILD_DIR}"
          zip -r ../site.zip .
        '''
      }
    }
    stage('Archive Artifact') {
      steps {
        archiveArtifacts artifacts: "${BUILD_DIR}/**", fingerprint: true
        archiveArtifacts artifacts: 'site.zip', fingerprint: true
      }
    }
    stage('Deploy to S3') {
      when {
        expression { return params.DEPLOY_TO_S3 }
      }
      steps {
        script {
          if (!params.S3_BUCKET?.trim()) {
            error('S3_BUCKET parameter must be provided when DEPLOY_TO_S3 is enabled.')
          }
          if (!params.AWS_CREDENTIALS_ID?.trim()) {
            error('AWS_CREDENTIALS_ID parameter must reference Jenkins credentials for deployment.')
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          withEnv(["DEPLOY_BUCKET=${params.S3_BUCKET}"]) {
            sh '''
              set -eux
              aws --version
              aws s3 sync "${BUILD_DIR}/" "s3://${DEPLOY_BUCKET}" --delete --region "${AWS_REGION}"
            '''
          }
        }
      }
    }
    stage('CloudFront Invalidation') {
      when {
        allOf {
          expression { return params.DEPLOY_TO_S3 }
          expression { return params.CREATE_CLOUDFRONT_INVALIDATION }
        }
      }
      steps {
        script {
          if (!params.CLOUDFRONT_DISTRIBUTION_ID?.trim()) {
            error('CLOUDFRONT_DISTRIBUTION_ID must be provided when cache invalidation is enabled.')
          }
          if (!params.AWS_CREDENTIALS_ID?.trim()) {
            error('AWS_CREDENTIALS_ID parameter must reference Jenkins credentials for cache invalidation.')
          }
        }
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: params.AWS_CREDENTIALS_ID, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          withEnv(["DISTRIBUTION_ID=${params.CLOUDFRONT_DISTRIBUTION_ID}"]) {
            sh '''
              set -eux
              aws cloudfront create-invalidation --distribution-id "${DISTRIBUTION_ID}" --paths '/*' --region "${AWS_REGION}"
            '''
          }
        }
      }
    }
  }
  post {
    success {
      echo 'Pipeline completed successfully.'
    }
    failure {
      echo 'Pipeline failed. Review the logs above for details.'
    }
    always {
      sh '''
        set +e
        echo 'Workspace contents:'
        ls -al
      '''
    }
  }
}
