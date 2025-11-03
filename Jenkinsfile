pipeline {
  agent any
  options { ansiColor('xterm') }

  parameters {
    booleanParam(name: 'RUN_FORMAT_CHECK', defaultValue: false, description: 'Run Prettier formatting checks (needs internet).')
    booleanParam(name: 'DEPLOY_TO_S3', defaultValue: true, description: 'Sync the built site to S3.')
    string(name: 'S3_BUCKET', defaultValue: 'convert.ogulcanaydogan.com', description: 'Destination S3 bucket.')
    booleanParam(name: 'CREATE_CLOUDFRONT_INVALIDATION', defaultValue: true, description: 'Invalidate CloudFront after deploy.')
    string(name: 'CLOUDFRONT_DISTRIBUTION_ID', defaultValue: 'E1N17NJWHJ4IYM', description: 'CloudFront Distribution ID (or leave blank to skip).')
    string(name: 'AWS_CREDENTIALS_ID', defaultValue: 'aws-jenkins', description: 'Jenkins credentials ID for AWS.')
  }

  stages {
    stage('Sanity') {
      steps {
        sh '''
          set -e
          echo "PATH=$PATH"
          which docker
          docker version
          aws --version
        '''
      }
    }

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build in Docker') {
      agent {
        docker { image 'node:20-alpine' }
      }
      steps {
        sh '''
          set -euo pipefail
          node -v
          npm -v || true
          rm -rf build && mkdir -p build/site
          rsync -av --delete --exclude build/ --exclude .git/ --exclude .gitignore ./ build/site/
        '''
        script {
          if (params.RUN_FORMAT_CHECK) {
            sh '''
              set -e
              if command -v npm >/dev/null 2>&1 && [ -f package.json ]; then
                npm ci || true
                npm run format:check || true
              else
                echo "No npm/package.json; skipping format check."
              fi
            '''
          }
        }
      }
    }

    stage('Deploy to S3') {
      when { expression { return params.DEPLOY_TO_S3 && params.S3_BUCKET?.trim() } }
      steps {
        withCredentials([aws(credentialsId: params.AWS_CREDENTIALS_ID, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(['AWS_DEFAULT_REGION=us-east-1']) {
            sh '''
              set -euo pipefail
              # Cache'li: HTML dışı dosyalar
              aws s3 sync build/site/ s3://$S3_BUCKET/ \
                --delete --exclude "*.html" --exclude ".git/*" --exclude ".DS_Store"

              # No-cache: HTML dosyaları
              aws s3 cp build/site/ s3://$S3_BUCKET/ \
                --recursive --exclude "*" --include "*.html" \
                --cache-control "no-cache, no-store, must-revalidate, max-age=0" \
                --content-type "text/html" --metadata-directive REPLACE

              echo "S3 listing summary:"
              aws s3 ls s3://$S3_BUCKET --recursive --human-readable --summarize | tail -n 50 || true
            '''
          }
        }
      }
    }

    stage('CloudFront Invalidate') {
      when {
        expression {
          return params.CREATE_CLOUDFRONT_INVALIDATION &&
                 params.CLOUDFRONT_DISTRIBUTION_ID?.trim()
        }
      }
      steps {
        withCredentials([aws(credentialsId: params.AWS_CREDENTIALS_ID, accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv(['AWS_DEFAULT_REGION=us-east-1']) {
            sh '''
              set -e
              aws cloudfront create-invalidation \
                --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
                --paths "/*"
            '''
          }
        }
      }
    }
  }

  post {
    // NOT: Burada ekstra node('label') istemiyoruz; agent any zaten workspace sağlıyor.
    always {
      sh 'du -sh . || true'
    }
    success {
      echo '✅ Pipeline completed successfully.'
    }
    failure {
      echo '❌ Pipeline failed — check logs above.'
    }
  }
}
