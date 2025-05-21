resource "aws_instance" "web2" {
  count = var.instance_count

  ami           = aws_ami_from_instance.ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.instance-sg.id ]
  subnet_id = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "var.vpc_name-${count.index}"
  }
  
  depends_on = [ aws_ami_from_instance.ami ]
}

resource "aws_key_pair" "deployer" {
  key_name   = "hello-key"
  public_key = file("//root/AWS-CS9/project/4aws-ami-test/keys/hello.pem.pub")
}

resource "aws_security_group" "instance-sg" {
  name        = "instance-sg"
  description = "security group for instance"
  vpc_id = aws_vpc.test.id

  ingress {
    description      = "Allow TLS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "Allow HTTP"
    from_port        = var.server_port
    to_port          = var.server_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow ICMP"
    from_port = 0
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance-sg"
  }
}