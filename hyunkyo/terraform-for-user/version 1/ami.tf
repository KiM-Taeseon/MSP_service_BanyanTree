data "aws_ami" "amzn2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????.?-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "instance_for_ami" {
  ami           = data.aws_ami.amzn2.id
  instance_type = var.instance_type
  vpc_security_group_ids = [ aws_security_group.instance-sg.id ]
  subnet_id = aws_subnet.public_subnets[0].id
  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "ami-instance"
  }
  user_data = <<-EOF
          #!/bin/bash
          yum -y install httpd git
          sed -i "s/^Listen 80$/Listen ${var.server_port}/" /etc/httpd/conf/httpd.conf
          git clone ${var.user_git} /var/www/html
          systemctl enable httpd --now
          touch /tmp/setup_complete
          EOF
}

resource "null_resource" "wait_for_web" {
  depends_on = [aws_instance.instance_for_ami]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/root/AWS-CS9/project/4aws-ami-test/keys/hello.pem")
      host        = aws_instance.instance_for_ami.public_ip
    }

    inline = [
      "while [ ! -f /tmp/setup_complete ]; do echo 'waiting for setup...'; sleep 10; done"
    ]
  }
}

resource "aws_ami_from_instance" "ami" {
  name               = "test-ami"
  source_instance_id = aws_instance.instance_for_ami.id

  depends_on = [ null_resource.wait_for_web ]
}

resource "null_resource" "stop_instance" {
  depends_on = [aws_ami_from_instance.ami]

  provisioner "local-exec" {
    command = <<EOT
      aws ec2 stop-instances --instance-ids ${aws_instance.instance_for_ami.id} --region ${var.region}
    EOT
  }
}