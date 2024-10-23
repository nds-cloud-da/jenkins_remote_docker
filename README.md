# Docker를 이용한 Jenkins Server 구축

## 관련 파일 git
[>> jenkins_remote_docker Clone](https://github.com/nds-cloud-da/jenkins_remote_docker.git)

## Docker 및 Git 설치
   - scripts/install_docker.sh 복사 후 ec2 에 붙여넣기
   - 'chmod +x install_docker.sh' 로 실행권한 부여 후 실행

   ```
   chmod +x install_docker.sh
   ./install_docker.sh
   ```

## jenkins 설치 방법
```
# git으로 jenkins_remote_docker 받기
  git clone https://github.com/nds-cloud-da/jenkins_remote_docker.git
# 도커 폴더로 이동
  cd jenkins_remote_docker/
# 실행중인 도커 컨테이너 확인
  docker ps
  make run
# 실행중인 도커 없을 때
  make run ( 도커 빌드? )
  docker-compose up ( 로그 바로 볼 수 있음 - jenkins initial admin password 바로 확인 가능 )
  docker-compose stop ( docker-compose 중지 )
  docker-compose up -d ( 백그라운드에서 실행 )
# (참고) 도커 컨테이너에 접속
  docker exec -it {CONTAINER ID} /bin/bash
  docker exec -it ed5afc7f581f /bin/bash
  # Unlock Jenkins
  cat /var/jenkins_home/secrets/initialAdminPassword
  db4fe92c42be4250a3e0f035c64b9c2f -> 젠킨스 비밀번호
```

## Docker 실행 후
```
# 크롬 열기
{ip}:8080 접속
젠킨스 initial 비밀번호 입력후, 순서대로 진행
```

## Pipeline Project 만들기
### General
1. 매개변수 등록

   | Name           | Value  | Type  | Description  |
   |----------------|--------|--------|--------|
   | BUILD_APP | common-module | String Parameter  | 빌드 모듈 명 (모듈이 없을 시 제외) |
   | ACTIVE_PROFILE | prod / release | String Parameter  | 환경파일 프로필 |
   | RESTART |  | Boolean Parameter  | 재시작  |
   | DEPLOY_BUILD_ID |  | String Parameter | 빌드 아이디 (젠킨스 빌드 번호) |
   | RUN_BUILD |  | Boolean Parameter | 빌드 실행 여부  |
   | BUILD_DOCKER_IMAGE |  | Boolean Parameter |  도커 빌드 여부 |
   | PUSH_DOCKER_IMAGE_PUSH |  | Boolean Parameter | 도커 레지스트리 등록 여부 |
   | RUN_TEST |  | Boolean Parameter | 테스트 코드 여부 |
   | PROMPT_FOR_DEPLOY |  | Boolean Parameter | 확인 메시지 |
   | DEPLOY_WORKLOAD |  | Boolean Parameter | 배포여부 |
   | DOCKER_USER | dev | String Parameter | 도커 유저 아이디 |
   | DOCKER_PASS |  | String Parameter | 도커 패스워드  |
   | AWS_ACCOUNT_ID | 882668563273 | String Parameter | aws ecr id |
   | DOCKER_IMAGE_KEY | build | String Parameter | aws ecr 리포지토리 이름  |
   | DOCKER_TAG | java-demo | String Parameter | 도커 태그 명   |
   | TARGET_SVR_USER | ec2-user | String Parameter | 배포할 서버 username  |
   | TARGET_SVR_PATH | /home/ec2-user | String Parameter |  배포할 서버 폴더  |
   | TARGET_SVR | 10.0.30.73 | String Parameter |  배포할 서버 주소   |

### Pipeline Script (Groovy)
1. api 예제
```
pipeline {
    agent any

    parameters {

        // 빌드 모듈 선택
        string(name : 'BUILD_APP', defaultValue : 'common-module', description : 'BUILD_APP')
        string(name : 'ACTIVE_PROFILE', defaultValue : 'prod', description : 'ACTIVE_PROFILE')


        // 빌드 플래그
        booleanParam(name : 'RESTART', defaultValue : false, description : 'RESTART')
        string(name : 'DEPLOY_BUILD_ID', defaultValue : '', description : 'DEPLOY_BUILD_ID')

        booleanParam(name : 'RUN_BUILD', defaultValue : true, description : '빌드실행 여부')
        booleanParam(name : 'BUILD_DOCKER_IMAGE', defaultValue : true, description : '도커 빌드 여부')
        booleanParam(name : 'PUSH_DOCKER_IMAGE_PUSH', defaultValue : true, description : '도커 레지스트리 등록 여부')
        booleanParam(name : 'RUN_TEST', defaultValue : false, description : '테스트 코드 여부')
        booleanParam(name : 'PROMPT_FOR_DEPLOY', defaultValue : true, description : '확인 메시지')
        booleanParam(name : 'DEPLOY_WORKLOAD', defaultValue : true, description : '배포여부')


        // 도커
        string(name : 'DOCKER_USER', defaultValue : 'dev', description : 'DOCKER_USER')
        string(name : 'DOCKER_PASS', defaultValue : '', description : 'DOCKER_PASS')

        // CI
        string(name : 'AWS_ACCOUNT_ID', defaultValue : '882668563273', description : 'AWS_ACCOUNT_ID')
        string(name : 'DOCKER_IMAGE_KEY', defaultValue : 'build', description : 'DOCKER_IMAGE_KEY')
        string(name : 'DOCKER_TAG', defaultValue : 'java-demo', description : 'DOCKER_TAG')

        // CD
        string(name : 'TARGET_SVR_USER', defaultValue : 'ec2-user', description : 'TARGET_SVR_USER')
        string(name : 'TARGET_SVR_PATH', defaultValue : '/home/ec2-user', description : 'TARGET_SVR_PATH')
        string(name : 'TARGET_SVR', defaultValue : '10.0.40.237', description : 'TARGET_SVR')
    }

    environment {
        REGION = "ap-northeast-2"
        EC2_BUILD_APP = "${params.BUILD_APP}"
        ECR_REPOSITORY = "${params.AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com"
        ECR_DOCKER_IMAGE = "${params.AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com/${params.DOCKER_IMAGE_KEY}"
        ECR_DOCKER_TAG = "${params.DOCKER_TAG}-${currentBuild.number}"
        ACTIVE_PROFILE = "${params.ACTIVE_PROFILE}"

        ECR_RESTART_TAG = "${params.DOCKER_TAG}-${params.DEPLOY_BUILD_ID}"
    }

    stages {

        stage('GIT') {
            steps {
                echo "GIT Progress"
                git branch: 'develop', credentialsId: 'git-ssh', url: 'git@github.com:nds-cloud-da/springboot-demo.git'
            }
        }

        stage('빌드') {
            when {
                expression { return params.RUN_BUILD }
            }
            steps {

                echo "Build Progress"
                sh '''
                    chmod 744 ./gradlew
                    ./gradlew common-module:clean common-module:build
                   '''
            }
        }

        stage('테스트') {
            when {
                expression { return params.RUN_TEST }
            }
            steps {
                echo "Stage Test"
            }
        }

        stage('도커 이미지') {
            when {
                expression { return params.BUILD_DOCKER_IMAGE }
            }
            steps {
                echo "Stage Docker Build"
                sh'''
                    cd ${EC2_BUILD_APP}
                    pwd
                    docker build --tag ${ECR_DOCKER_IMAGE}:${ECR_DOCKER_TAG} .
                '''
            }
        }

        stage('도커 배포') {
            when {
                expression { return params.PUSH_DOCKER_IMAGE_PUSH }
            }
            steps {
                echo "Push Docker Image to ECR"
                sh'''
                    aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                    docker push ${ECR_DOCKER_IMAGE}:${ECR_DOCKER_TAG}
                '''
            }
        }

        stage('배포') {
            when {
                expression { return !params.RESTART && params.DEPLOY_WORKLOAD }
            }
            steps {
                sh'''
                    echo ${ECR_DOCKER_IMAGE}
                    echo ${ECR_DOCKER_TAG}
                    pwd
                '''
                sshagent (credentials: ['aws_ec2_api_ssh'], ignoreMissing: true) {
                    sh """#!/bin/bash
                        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                                                ${params.BUILD_APP}/docker-compose.yml \
                                                ${params.TARGET_SVR_USER}@${params.TARGET_SVR}:${params.TARGET_SVR_PATH};

                        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                                                ${params.BUILD_APP}/run.sh \
                                                ${params.TARGET_SVR_USER}@${params.TARGET_SVR}:${params.TARGET_SVR_PATH};

                        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                            ${params.TARGET_SVR_USER}@${params.TARGET_SVR} \
                            'chmod +x run.sh; ./run.sh ${ACTIVE_PROFILE} ${REGION} ${ECR_REPOSITORY} ${ECR_DOCKER_IMAGE} ${ECR_DOCKER_TAG}';

                    """
                }
                echo "Deploy Workload"
            }
        }

        stage('재시작') {
            when {
                expression { return params.RESTART && !params.DEPLOY_WORKLOAD }
            }
            steps {

                sshagent (credentials: ['aws_ec2_api_ssh'], ignoreMissing: true) {
                    sh """#!/bin/bash
                        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                                                ${params.BUILD_APP}/docker-compose.yml \
                                                ${params.TARGET_SVR_USER}@${params.TARGET_SVR}:${params.TARGET_SVR_PATH};

                        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                                                ${params.BUILD_APP}/run.sh \
                                                ${params.TARGET_SVR_USER}@${params.TARGET_SVR}:${params.TARGET_SVR_PATH};

                        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
                            ${params.TARGET_SVR_USER}@${params.TARGET_SVR} \
                            'chmod +x run.sh; ./run.sh ${ACTIVE_PROFILE} ${REGION} ${ECR_REPOSITORY} ${ECR_DOCKER_IMAGE} ${ECR_RESTART_TAG}';

                    """
                }
                echo "Deploy Workload"
            }
        }

    }
    post {
        cleanup {
            echo "Post cleanup"
        }
    }
}

### (중요) Credentials 설정
1. git 키 설정
- Jenkins 관리 > Manage Credentials > Stores scoped to Jenkins > Global credentials (unrestricted) > Add Credentials
- Kind: SSH Username with private key
- ID: git-ssh
- Description: git-ssh
- ** Username ** : git
- Private Key: git에 등록된 키 값

2. ec2-user 키 설정
- Jenkins 관리 > Manage Credentials > Stores scoped to Jenkins > Global credentials (unrestricted) > Add Credentials
- Kind: SSH Username with private key
- ID: aws_ec2_api_ssh
- Description: aws_ec2_api_ssh
- ** Username ** : ec2-user
- Private Key: Jenkins에 등록된 키 값
