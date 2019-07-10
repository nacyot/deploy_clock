# 테라폼 튜토리얼

## 테라폼 기초
### Requirements
* 노트북
* AWS 계정

### 테라폼은?
* Infrastructure as Code
* **코드로 클라우드 리소스들을 관리** <- 핵심

### 주요 개념
* 프로비저닝(Provisioning)
* 프로바이더(Provider)
* 리소스(Resource)
* 데이터(Data)
* HCL(Hashicorp Configuration Language)
* 계획(Plan)
* 적용(Apply)

### HCL
* Hashicorp Configuration Language
* 테라폼에서 사용하는 공식 언어
* JSON 호환
* 리소스 정의 순서는 무관 (의존성 자동 파악)

기본적인 형태
```
resource "RESOURCE_TYPE" "RESOURCE_NAME" {
}
```

인자값 지정
```
resource "RESOURCE_TYPE" "RESOURCE_NAME" {
  ARG1 = "value"
  ARG2 = "value"
}
```

참조
```
resource "A" "B" { }
resource "Y" "Z" {
  ARG1 = A.B.ATTR
}
```

### 매뉴얼 읽기
* [AWS: aws_instance - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/instance.html)

## 튜토리얼 아키텍처

## Iteration 1: EC2 Instance

### 환경 준비
* AWS 액세스 키를 생성해주세요.
	* [아마존 웹 서비스 IAM 사용자의 액세스 키 발급 및 관리 | 44bits.io](https://www.44bits.io/ko/post/publishing_and_managing_aws_user_access_key)
	* 액세스 키는 안전하게 보관해주세요.
* 테라폼을 설치해주세요.
	* [Download Terraform - Terraform by HashiCorp](https://www.terraform.io/downloads.html)
	* [Terraform – Getting Started – Install Terraform on Windows, Linux and Mac OS](https://www.vasos-koupparis.com/terraform-getting-started-install/)

macOS(homebrew)
```
$ brew install terraform
```

설치 확인
```
$ terraform version
```

### 테라폼 프로젝트 준비
다음 명령어들을 차례대로 실행하고, 결과를 확인합니다.

```
## 프로젝트 디렉터리 생성
$ mkdir terraform-clock
$ cd terraform-clock

## 첫 plan 명령어
$ terraform plan

## ec2.tf 파일 생성
$ touch ec2.tf

## 테라폼 프로젝트 초기화(실제로는 아무일도 일어나지 않음)
## init 실행시 사용중인 프로바이더나 모듈을 가져옵니다
$ terraform init

## 다시 plan
$ terraform plan

## 아무것도 없는 상태에서 apply
$ terraform apply
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

# apply해서 state 파일이 만들어집니다
$ cat terraform.tfstate
```

### AWS 프로바이더 셋업
`configuration.tf` 파일을 만들고 다음 내용을 추가합니다.

```
provider "aws" {
  region     = "us-west-2"
  access_key = "my-access-key"
  secret_key = "my-secret-key"
}
```

다음 명령어들을 차례대로 실행하고, 결과를 확인합니다.

```
$ terraform plan

# aws provider 설치, .terraform 디렉터리 생성
$ terrafrom init

$ terraform plan

# 설치된 provider 정보도 함께 보여줍니다
$ terraform version
```

### 첫 테라폼 코드: EC2 인스턴스 예제
`ec2.tf` 파일을 작성하고 다음 내용을 추가합니다.

```
resource "aws_instance" "clock" {
  ami = "ami-0b5edf72c627a56c9" # Ubuntu AMI
  instance_type = "t2.micro"

  tags = {
    Name = "HelloTerraform"
  }
}
```

다음 명령어들을 차례대로 실행하고, 결과를 확인합니다.

```
## plan 명령어를 실행하면, 생성될 EC2 인스턴스의 정보를 보여줍니다.
$ terraform plan

## 실제로 EC2 인스턴스를 생성합니다. 중간에 정말 생성하냐는 질문에 yes를 입력해줍니다.
$ terraform apply
```

생성된 EC2의 IP를 받아오기 위해 `output` 문법을 사용해봅니다.

`output.tf` 파일을 만들고 다음 내용을 작성합니다.

```
output "public_ip" {
  value = aws_instance.clock.public_ip
}
```

다시 `terraform apply`를 실행하면 맨 아래에 output에 추가한 내용이 출력됩니다. 이 IP로 SSH에 접속해봅니다.

```
## 접속 안 됨...
$ ssh ubuntu@<EC2_PUBLIC_IP>
```

지금까지 작성한 프로젝트의 구조를 살펴봅니다.

```
$ tree
.
├── configuration.tf
├── ec2.tf
├── output.tf
├── terraform.tfstate
└── terraform.tfstate.backup
```

### 인스턴스에 SSH 접속하기
웹콘솔에 접속해서 생성된 EC2 인스턴스의 정보를 확인해봅니다. 시큐리티 그룹을 확인해보면 SSH 포트가 열려있지 않은 것을 확인할 수 있습니다. 또한 SSH 접속을 위한 키 페어 설정도 필요합니다.

`ec2.tf` 파일에 다음 내용을 추가합니다. 위치는 무관하지만 `aws_instance` 리소스 앞에 추가하는 것을 권장합니다.

```
resource "aws_security_group" "ec2" {
  name = "terraform-ec2-sg"
  description = "allow ssh"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

`terraform apply`로 시큐리티 그룹을 생성합니다.

키페어 추가를 위해 다음 내용을 `ec2.tf`에 추가합니다.
```
resource "aws_key_pair" "web_admin" {
  key_name = "web_admin"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
```

이 때 `public_key`의 경로는 자신이 사용하는 SSH키의 퍼블릭 키 경로가 되어야합니다.

`terraform apply`로 키 페어를 추가해줍니다.

`ec2.tf`에서 처음에 작성 `aws_instance.clock01` 리소스의 내용을 다음과 같이 변경합니다. `vpc_security_group_ids`와 `key_name`이 추가되었습니다.
```
resource "aws_instance" "clock01" {
  ami           = "ami-0b5edf72c627a56c9"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name      = aws_key_pair.admin.key_name

  tags = {
    Name = "HelloTerraform"
  }
}
```

다시 `terraform apply`을 실행합니다.

이제 SSH에 접속이 가능할 것입니다.

```
# 1~2분 정도 기다린 후 SSH 접속
$ ssh ubuntu@$<EC2_PUBLIC_IP>
```

### 도커 설치 및 컨테이너 실행
```
# Docker 설치
$ curl -s https://get.docker.com/ | sudo sh

# 도커로 nacyot/clock 이미지 실행하기
$ sudo docker run -d -p 80:4567 nacyot/clock:latest

$ curl 0.0.0.0:80
```

### 관련 리소스 목록
* [Provider: AWS - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/index.html)
* [AWS: aws_security_group - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/security_group.html)
* [AWS: aws_instance - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/instance.html)

### 추가 과제
* 여기까지 적용된 `terraform.tfstate` 내용을 살펴봅니다.
* 앞서 실행한 도커 컨테이너는 외부에서 접속이 어렵습니다. 접속 가능하도록 해보세요.
	* 힌트: 시큐리티 그룹에서 도커가 사용하는 포트를 열어줘야합니다.
* AWS 프로바이더 설정시 직접 값을 입력하는 대신 환경변수로 지정해보세요.
	* 힌트: [Provider: AWS - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/index.html)
* 현재 IP에서만 SSH 접속이 가능하도록 sceurity group을 수정해보세요.
	* 힌트: My IP 같은 서비스를 사용해 자신의 퍼블릭 IP를 확인하고 CIDR로 지정해보세요.
* `terraform destroy` 후 다시 `terraform apply` 해보세요.
	* 단, 도커 컨테이너는 SSH 접속해서 다시 실행해줘야합니다.

## Iteration 2: Elastic Load Balancer
### Security Group
`elb.tf` 파일을 작성하고 시큐리티 그룹을 추가합니다.
```
resource "aws_security_group" "lb" {
  name = "terraform-elb-sg"
  description = "allow http"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### VPC, Subnet 데이터 가져오기
ELB 리소스를 생성하기 위해서는 VPC와 서브넷 정보가 필요합니다. AWS 프로바이더의 data를 사용해서 이 정보들을 가져옵니다.

`elb.tf`에 다음 내용을 추가합니다.

```
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
```

### 로드 밸런서 작성
로드 밸런서 리소스를 작성합니다. 앞서 생성한 시큐리티 그룹을 사용합니다. 또한 위에서 data로 가져온 서브넷 아이디를 지정합니다.

`elb.tf`에 다음 내용을 추가합니다.

```
resource "aws_lb" "clock" {
  name               = "clock-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets = data.aws_subnet_ids.default.ids
  enable_deletion_protection = false
}
```

생성된 로드 밸런서를 웹 콘솔에서 확인해봅니다.

로드 밸런서에 접속할 수 있는 주소를 출력하기 위해 `output.tf`에 다음 내용을 추가해줍니다.

```
output "elb_address" {
  value = aws_lb.clock.dns_name
}
```

이 주소에 접속해봅니다. 아직은 앞서 확인한 clock 서버에 연결되지 않습니다.

### 타깃 그룹 작성
타깃 그룹을 생성합니다.

`elb.tf`에 다음 내용을 추가합니다.

```
resource "aws_lb_target_group" "clock" {
  name     = "clock"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}
```

### 로드 밸런서 리스너 작성
로드 밸런서와 타깃 그룹을 연결하는 리스너를 연결합니다.

`elb.tf`에 다음 내용을 추가합니다.

```
resource "aws_lb_listener" "clock_http" {
  load_balancer_arn = aws_lb.clock.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clock.arn
  }
}
```

### 타깃 그룹에 타깃 추가
타깃 그룹에 앞서 생성한 인스턴스를 연결합니다.

`elb.tf`에 다음 내용을 추가합니다.

```
resource "aws_lb_target_group_attachment" "clock01" {
  target_group_arn = aws_lb_target_group.clock.arn
  target_id        = aws_instance.clock01.id
  port             = 80
}
```

이제 다시 로드 밸런서의 주소에 접속해봅니다.

### 리소스 목록
* [AWS: aws_lb - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/lb.html)
* [AWS: aws_lb_listener - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/lb_listener.html)
* [AWS: aws_lb_target_group - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html)

### 추가 과제
* 인스턴스를 하나 더 만들고 타깃그룹에 연결해봅니다. 로드 밸런서가 두 인스턴스에 모두 연결해주는지 확인해봅니다.
* VPC와 서브넷 정보를 common.tf 파일로 분리하고, `ec2.tf`의 인스턴스에서 명시적으로 subnet을 지정해봅니다.
	* [AWS: aws_instance - Terraform by HashiCorp](https://www.terraform.io/docs/providers/aws/r/instance.html)에서 서브넷 지정 방법을 참고합니다.
* ELB에서 직접 HTTPS 처리하는 것이 가능합니다. 이 때 어떤 리소스들이 필요한지 구상해봅니다.
	* 공인인증서를 사용해 HTTPS 연결을 하려면 직접 구매한 도메인이 필요합니다.
