# 아마존 웹 서비스에 웹 서버 배포

## 프로젝트

* `./clock` - 간단한 Sinatra 웹서버 애플리케이션

```
# 서버 실행
$ ruby ./app.rb
```

## Dockerize

* Dockerfile: Docker 이미지를 만들기 위한 파일
* Dockerfile은 프로젝트의 루트 디렉터리에 배치

Dockerfile 예제

```
FROM ruby:2.6

WORKDIR /app
ADD ./Gemfile ./Gemfile.lock /app/
RUN bundle install
ADD . /app
CMD ruby ./app.rb -o 0.0.0.0
```

다섯가지만 알면 바로 시작 가능!

* FROM - 베이스 이미지를 지정
* WORKDIR - 작업 디렉터리를 지정
* ADD - 도커 이미지에 파일을 추가
* RUN - 이미지 기반으로 명령어를 실행
* CMD - 이미지의 기본 명령어 지정

```
# 도커 이미지 빌드
$ docker build -t nacyot/clock .

# 도커 컨테이너 실행
$ docker run -it -p 80:4567 nacyot/clock:latest

# 도커 허브 로그인
$ docker login

# 도커 허브에 이미지 업로드
$ docker push nacyot/clock:latest
```

도커에 대해서 더 자세한 내용은 다음 글들을 참고해주세요.

* [도커(Docker) 튜토리얼 : 깐 김에 배포까지 | 44bits.io](https://www.44bits.io/ko/post/easy-deploy-with-docker)
* [초보를 위한 도커 안내서 - 도커란 무엇인가?](https://subicura.com/2017/01/19/docker-guide-for-beginners-1.html)

## AWS 배포 준비

* [아마존 웹서비스 커맨드라인 인터페이스(AWS CLI) 기초 | 44bits.io](https://www.44bits.io/ko/post/aws_command_line_interface_basic)
* [커맨드라인 JSON 프로세서 jq : 기초 문법과 작동원리 | 44bits.io](https://www.44bits.io/ko/post/cli_json_processor_jq_basic_syntax)

## 배포를 위한 변수값 준비

VPC, Subnet, AMI 등 배포 작업에 필요한 변수들을 먼저 준비. AWS 계정 기본 상태(Default VPC)를 사용한다고 가정.

```sh
# 기본 VPC의 ID 값
VPC_ID=$(aws ec2 describe-vpcs | jq -r '.Vpcs[].VpcId')

# 기본 VPC에 속한 Subnet들의 ID
SUBNET_IDS=$(aws ec2 describe-subnets | jq -r '.Subnets | map(.SubnetId) | join(" ")')
FIRST_SUBNET_ID=$(echo $SUBNET_IDS | cut -d' ' -f1)
SECOND_SUBNET_ID=$(echo $SUBNET_IDS | cut -d' ' -f2)
THIRD_SUBNET_ID=$(echo $SUBNET_IDS | cut -d' ' -f3)

# 기본 보안 그룹
DEFAULT_SG_ID=$(aws ec2 describe-security-groups --group-name=default | jq -r '.SecurityGroups[].GroupId')

# Ubuntu AMI
UBUNTU_AMI_ID='ami-0b5edf72c627a56c9'

# DOMAIN
DOMAIN='44bits.io'
DOMAIN_EC2='clock.44bits.io'
DOMAIN_ELB='clockl1.44bits.io'
```

## EC2 용 보안 그룹 생성

ec2web: 22, 80 포트 인바운트를 열어주는 보안 그룹 작성

```sh
# 비어있는 보안 그룹을 생성
aws ec2 create-security-group \
  --group-name ec2web \
  --description ec2web \
  --vpc-id "${VPC_ID}"

# 방금 생성한 보안 그룹의 ID를 EC2WEB_SG_ID 변수에 저장
EC2WEB_SG_ID=$(aws ec2 describe-security-groups --group-name=ec2web | jq -r '.SecurityGroups[].GroupId')

# 22번 포트 오픈 규칙 추가(SSH)
aws ec2 authorize-security-group-ingress \
  --group-id $EC2WEB_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# 80번 포트 오픈 규칙 추가(HTTP)
aws ec2 authorize-security-group-ingress \
  --group-id $EC2WEB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

## 첫 번째 EC2 인스턴스 생성

웹 서버 배포용 첫 EC2 인스턴스 생성

* SSH 키는 미리 설정해두어야함(EC2 -> Key Pairs)
* 앞서 생성한 EC2용 보안 그룹을 사용
* 외부에서 접속 가능하도록 퍼블릭 IP를 할당해줌(`--associate-public-ip-address`)
* `key-name`은 AWS 계정에 설정된 SSH 키를 지정

```sh
aws ec2 run-instances \
  --image-id $UBUNTU_AMI_ID \
  --instance-type t2.small \
  --security-group-ids $EC2WEB_SG_ID $DEFAULT_SG_ID \
  --subnet-id $FIRST_SUBNET_ID \
  --associate-public-ip-address \
  --key-name nacyot \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Web01}]'

# Web01 서버 IP와 ID를 변수로 저장
WEB01_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Web01" | jq -r '.Reservations[].Instances[].PublicIpAddress')
WEB01_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Web01" | jq -r '.Reservations[].Instances[].InstanceId')

# 1~2분 정도 기다린 후 SSH 접속
ssh ubuntu@$WEB01_IP

# Docker 설치
curl -s https://get.docker.com/ | sudo sh

# 도커로 nacyot/clock 이미지 실행하기
sudo docker run -d -p 80:4567 nacyot/clock:latest
```

## Route 53으로 도메인 연결하기(1)

A Record 추가: $DOMAIN_EC2, EC2 IP

## ELB 용 보안 그룹 작성

```sh
aws ec2 create-security-group \
  --group-name elbweb \
  --description elbweb \
  --vpc-id "${VPC_ID}"

ELBWEB_SG_ID=$(aws ec2 describe-security-groups --group-name=elbweb | jq -r '.SecurityGroups[].GroupId')

# HTTP 접속 용 규칙 추가
aws ec2 authorize-security-group-ingress \
  --group-id $ELBWEB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# HTTPS 접속 용 규칙 추가
aws ec2 authorize-security-group-ingress \
  --group-id $ELBWEB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

## 로드 밸런서 작성

```sh
# 로드 밸런서 생성
aws elbv2 create-load-balancer \
  --name web-load-balancer \
  --subnets $FIRST_SUBNET_ID $SECOND_SUBNET_ID $THIRD_SUBNET_ID \
  --security-groups $ELBWEB_SG_ID $DEFAULT_SG_ID

LB_ARN=$(aws elbv2 describe-load-balancers --name web-load-balancer | jq -r '.LoadBalancers[0] | .LoadBalancerArn')

# 타깃 그룹 생성
aws elbv2 create-target-group \
  --name web-target-group \
  --protocol HTTP --port 80 --vpc-id "${VPC_ID}"

TG_ARN=$(aws elbv2 describe-target-groups --name web-target-group | jq -r '.TargetGroups[0] | .TargetGroupArn')

# 로드 밸런서에 타깃 그룹을 리스너로 등록
aws elbv2 create-listener \
  --protocol HTTP --port 80 \
  --load-balancer-arn="${LB_ARN}" \
  --default-actions "Type=forward,TargetGroupArn=${TG_ARN}"

# Web01 서버를 타겟 그룹에 등록
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$WEB01_ID

# 로드 밸런서의 DNS 주소 출력
aws elbv2 describe-load-balancers --name web-load-balancer | jq -r '.LoadBalancers[0].DNSName'
```

## Route 53으로 도메인 연결하기(2)

A Record(alias) 추가: $DOMAIN_ELB, ELB DNSName


## ACM을 사용해 인증서 발급

웹 콘솔에서 작업 후 변수로 저장

```sh
ACM_ARN=$(aws acm list-certificates | jq -r ".CertificateSummaryList[] | select(.DomainName == \"*.$DOMAIN\") | .CertificateArn")
```

## 로드 밸런서에 HTTPS 용 리스너 추가

```sh
aws elbv2 create-listener \
  --protocol HTTPS --port 443 \
  --load-balancer-arn="${LB_ARN}" \
  --default-actions "Type=forward,TargetGroupArn=${TG_ARN}" \
  --certificates "CertificateArn=${ACM_ARN}" \
  --ssl-policy ELBSecurityPolicy-2016-08
```

## 두 번째 인스턴스 작업

```sh
aws ec2 run-instances \
  --image-id $UBUNTU_AMI_ID \
  --instance-type t2.small \
  --security-group-ids $EC2WEB_SG_ID $DEFAULT_SG_ID \
  --subnet-id $FIRST_SUBNET_ID \
  --associate-public-ip-address \
  --key-name nacyot \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Web02}]'

WEB02_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Web02" | jq -r '.Reservations[].Instances[].PublicIpAddress')
WEB02_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=Web02" | jq -r '.Reservations[].Instances[].InstanceId')

ssh ubuntu@$WEB02_IP
curl -s https://get.docker.com/ | sudo sh
sudo docker run -d -p 80:4567 nacyot/clock:latest
```

두 번째 인스턴스도 타깃그룹에 등록

```sh
aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=$WEB02_ID
```

## 생성한 리소스 삭제

* ELB, EC2 리소스 정리
* Route53 Record, ACM 인증서는 웹콘솔에서 삭제

```sh
aws elbv2 delete-load-balancer --load-balancer-arn=$LB_ARN
aws elbv2 delete-target-group --target-group-arn=$TG_ARN
aws ec2 terminate-instances --instance-id=$WEB01_ID
aws ec2 terminate-instances --instance-id=$WEB02_ID
aws ec2 delete-security-group --group-name ec2web
aws ec2 delete-security-group --group-name elbweb
```

# 더 공부하기

* [아마존 엘라스틱 컨테이너 서비스(ECS)와 도커(Docker)로 시작하는 컨테이너 오케스트레이션 | 44bits.io](https://www.44bits.io/ko/post/container-orchestration-101-with-docker-and-aws-elastic-container-service)
