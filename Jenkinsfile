pipeline {
  agent any
  options {
    ansiColor('xterm')
    disableConcurrentBuilds()
    timestamps()
  }

  // Parametre yok → “Build Now”
  environment {
    // ---- Kendine göre düzenle ----
    S3_BUCKET                   = 'convert.ogulcanaydogan.com'
    AWS_CREDENTIALS_ID          = 'skip'      // Jenkins credentials ID; leave 'skip' to use existing AWS CLI creds
    AWS_DEFAULT_REGION          = 'us-east-1'
    CREATE_CLOUDFRONT_INVALIDATION = 'true'   // istemezsen 'false'
    CLOUDFRONT_DISTRIBUTION_ID  = 'skip'      // CF yoksa 'skip' bırak
    // --------------------------------
  }

  // GitHub → Webhook ile otomatik tetikleme
  triggers { githubPush() }

  stages {
    stage('Preflight') {
      steps {
        sh '''
          set -e
          echo "PATH=$PATH"
          whoami
          git --version
          aws --version
        '''
      }
    }

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build') {
      steps {
        sh '''
          set -e
          echo "Preparing static files..."
          rm -rf build && mkdir -p build/site

          # rsync varsa kullan; yoksa cp fallback
          if command -v rsync >/dev/null 2>&1; then
            rsync -av --delete \
              --exclude build/ --exclude .git/ --exclude .gitignore \
              ./ build/site/
          else
            find . -maxdepth 1 ! -name build ! -name .git ! -name .gitignore ! -name '.' -exec cp -a {} build/site/ \\;
          fi

          # İstersen burada minify/format vs. adımları ekleyebilirsin
        '''
      }
    }

    stage('Deploy to S3') {
      steps {
        script {
          def credentialsId = env.AWS_CREDENTIALS_ID?.trim()
          def useManagedCredentials = credentialsId && credentialsId != 'skip'
          def deployToS3 = {
            sh '''
              set -euo pipefail
              aws sts get-caller-identity

              # HTML dışı içerikler: cache'li
              aws s3 sync build/site/ s3://$S3_BUCKET/ \
                --delete \
                --exclude "*.html" --exclude ".DS_Store" --exclude ".git/*"

              # HTML dosyaları: no-cache + doğru content-type
              aws s3 cp build/site/ s3://$S3_BUCKET/ \
                --recursive --exclude "*" --include "*.html" \
                --cache-control "no-cache, no-store, must-revalidate, max-age=0" \
                --content-type "text/html" \
                --metadata-directive REPLACE
            '''
          }

          if (useManagedCredentials) {
            withCredentials([aws(credentialsId: credentialsId,
                                 accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                 secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
              deployToS3()
            }
          } else {
            echo 'AWS_CREDENTIALS_ID not provided; using existing AWS CLI credentials'
            deployToS3()
          }
        }
      }
    }

    stage('CloudFront Invalidate') {
      when {
        expression {
          env.CREATE_CLOUDFRONT_INVALIDATION == 'true' &&
          env.CLOUDFRONT_DISTRIBUTION_ID?.trim() &&
          env.CLOUDFRONT_DISTRIBUTION_ID != 'skip'
        }
      }
      steps {
        script {
          def credentialsId = env.AWS_CREDENTIALS_ID?.trim()
          def useManagedCredentials = credentialsId && credentialsId != 'skip'
          def invalidateCloudFront = {
            sh '''
              set -euo pipefail
              aws cloudfront create-invalidation \
                --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
                --paths "/*"
            '''
          }

          if (useManagedCredentials) {
            withCredentials([aws(credentialsId: credentialsId,
                                 accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                                 secretKeyVariable: 'AWS_SECRET_ACCESS_KEY')]) {
              invalidateCloudFront()
            }
          } else {
            echo 'AWS_CREDENTIALS_ID not provided; using existing AWS CLI credentials'
            invalidateCloudFront()
          }
        }
      }
    }
  }
}
