pipeline {
  agent any
  options { ansiColor('xterm') }

  // 1) Hard-coded (or from Jenkins global env) — no params
  environment {
    DEPLOY_TO_S3 = 'true'
    CREATE_CLOUDFRONT_INVALIDATION = 'true'
    S3_BUCKET = 'convert.ogulcanaydogan.com'
    CLOUDFRONT_DISTRIBUTION_ID = 'E1N17NJWHJ4IYM'   // or 'skip'
    AWS_CREDENTIALS_ID = 'aws-jenkins'
    AWS_DEFAULT_REGION = 'us-east-1'
  }

  triggers { githubPush() }

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

    stage('Checkout') { steps { checkout scm } }

    stage('Build in Docker') {
      agent { docker { image 'node:20-alpine' } }
      steps {
        sh '''
          set -euo pipefail
          node -v
          npm -v || true
          rm -rf build && mkdir -p build/site
          rsync -av --delete --exclude build/ --exclude .git/ --exclude .gitignore ./ build/site/
        '''
      }
    }

    stage('Deploy to S3') {
      when {
        expression { env.DEPLOY_TO_S3 == 'true' && env.S3_BUCKET?.trim() }
      }
      steps {
        withCredentials([aws(credentialsId: env.AWS_CREDENTIALS_ID,
                             accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                             secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -euo pipefail
            # HTML dışı (cache'li)
            aws s3 sync build/site/ s3://$S3_BUCKET/ \
              --delete --exclude "*.html" --exclude ".git/*" --exclude ".DS_Store"

            # HTML (no-cache)
            aws s3 cp build/site/ s3://$S3_BUCKET/ \
              --recursive --exclude "*" --include "*.html" \
              --cache-control "no-cache, no-store, must-revalidate, max-age=0" \
              --content-type "text/html" --metadata-directive REPLACE
          '''
        }
      }
    }

    stage('CloudFront Invalidate') {
      when {
        expression {
          env.CREATE_CLOUDFRONT_INVALIDATION == 'true' &&
          env.CLOUDFRONT_DISTRIBUTION_ID?.trim() && env.CLOUDFRONT_DISTRIBUTION_ID != 'skip'
        }
      }
      steps {
        withCredentials([aws(credentialsId: env.AWS_CREDENTIALS_ID,
                             accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                             secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
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

  post {
    always { sh 'du -sh . || true' }
    success { echo '✅ Pipeline completed successfully.' }
    failure { echo '❌ Pipeline failed — check logs above.' }
  }
}
