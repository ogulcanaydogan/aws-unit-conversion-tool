pipeline {
  agent any
  options { ansiColor('xterm') }
  triggers { githubPush() }

  environment {
    S3_BUCKET = 'convert.ogulcanaydogan.com'   // ihtiyacına göre değiştir
    CF_DISTRIBUTION_ID = 'E1N17NJWHJ4IYM'      // varsa doldur, yoksa 'skip'
    AWS_REGION = 'us-east-1'
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

    stage('Build in Docker (node:20-alpine)') {
      agent {
        docker {
          image 'node:20-alpine'
          // args '-u root'  // gerekirse
        }
      }
      steps {
        sh '''
          set -euo pipefail
          node -v
          npm -v || true   # npm gerekliyse paketlerini ekle
          rm -rf build && mkdir -p build/site
          rsync -av --delete --exclude build/ --exclude .git/ ./ build/site/
        '''
      }
    }

    stage('Deploy to S3') {
      steps {
        sh '''
          set -euo pipefail

          # HTML dışı dosyalar (cache'li)
          aws s3 sync build/site/ s3://$S3_BUCKET/ \
            --delete --exclude "*.html" --exclude ".git/*" --exclude ".DS_Store"

          # HTML dosyaları (no-cache)
          aws s3 cp build/site/ s3://$S3_BUCKET/ \
            --recursive --exclude "*" --include "*.html" \
            --cache-control "no-cache, no-store, must-revalidate, max-age=0" \
            --content-type "text/html" --metadata-directive REPLACE
        '''
      }
    }

    stage('Invalidate CloudFront (optional)') {
      when { expression { return env.CF_DISTRIBUTION_ID && env.CF_DISTRIBUTION_ID != 'skip' } }
      steps {
        sh '''
          set -e
          aws cloudfront create-invalidation \
            --distribution-id "$CF_DISTRIBUTION_ID" \
            --paths "/*"
        '''
      }
    }
  }

  post {
    always {
      // Post adımlarında workspace erişimi için node içine alıyoruz
      node {
        sh 'du -sh . || true'
      }
    }
  }
}
