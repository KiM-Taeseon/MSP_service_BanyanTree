variable "region" {
  type = string
  default = "ap-northeast-2"
}
variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}
variable "vpc_name" {
  type = string
  default = "test-vpc"
}
variable "id" {
  type = string
  default = "default-user"
}

variable "user_git" {
  description = "유저의 github repo 링크"
  type = string
  default = "https://github.com/kuzwolka/awswebtest.git"
}

variable "ec2type" {
  type = string
  default = "t3.micro"
}


variable "s3" {
  type = number
  default = 4
}

variable "server_port" {
  description = "webserver port"
  type = number
  default = 80
}

variable "ec2" {
  description = "number of instances"
  type = number
  default = 3
}

variable "availability_zones" {
  type = map(string)
  default = {
    "ap-northeast-1" = "ap-northeast-1a,ap-northeast-1c,ap-northeast-1d"
    "ap-northeast-2" = "ap-northeast-2a,ap-northeast-2b,ap-northeast-2c,ap-northeast-2d"
    "ap-northeast-3" = "ap-northeast-3a,ap-northeast-3b,ap-northeast-3c"

    "us-east-1" = "us-east-1a,us-east-1b,us-east-1c,us-east-1d,us-east-1e,us-east-1f"
    "us-east-2" = "us-east-2a,us-east-2b,us-east-2c"
    "us-west-1" = "us-west-1a,us-west-1c"
    "us-west-2" = "us-west-2a,us-west-2b,us-west-2c,us-west-2d"

    "ap-south-1" = "ap-south-1a,ap-south-1b,ap-south-1c"
    "ap-southeast-1" = "ap-southeast-1a,ap-southeast-1b,ap-southeast-1c"
    "ap-southeast-2" = "ap-southeast-2a,ap-southeast-2b,ap-southeast-2c"
  }
}

#------------- RDS
variable "rds" {
  description = "A map of key-value pairs"
  type        = map(string)
  default = {
    instnace_class = "db.t3.medium"
    engine_name = "mariadb"
    engine_version = "10.5.24"
    username = "admin"
    password = "plzCHANGE123"
  }
}

variable "rds-allocated_storage" {
  description = "allocated_storage for db instance"
  type = number
  default = 20
}

variable "rds-ports" {
  description = "rds ports by engines"
  type        = map(number)
  default = {
    mariadb = 3306
    mysql = 3306
    aurora = 3306
    sql = 1433
    postgresql = 5432
    oracle = 1521
  }
}
variable "db_count" {
  description = "how many db instances?"
  type = number
  default = 2
}

variable "db_identifier" {
  type = string
  default = "default-db"
}