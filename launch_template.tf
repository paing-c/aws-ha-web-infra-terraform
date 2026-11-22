data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  # Match the standard AL2023 image and exclude the minimal variant.
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # Escape the project name before displaying it as HTML text.
  project_name_html = replace(replace(replace(var.project_name, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
}

resource "aws_launch_template" "web" {
  name_prefix            = "${local.name_prefix}-web-"
  image_id               = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  # Standard mode avoids charges for surplus CPU credits.
  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  depends_on = [aws_iam_role_policy_attachment.ec2_ssm]

  user_data = base64encode(<<-USER_DATA
    #!/bin/bash
    set -euo pipefail

    dnf install -y nginx

    # Use a short-lived IMDSv2 token for both metadata requests.
    metadata_url="http://169.254.169.254/latest"
    token=$(curl -fsS --noproxy '*' --max-time 5 --retry 3 -X PUT \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 60" "$metadata_url/api/token")
    instance_id=$(curl -fsS --noproxy '*' --max-time 5 --retry 3 \
      -H "X-aws-ec2-metadata-token: $token" "$metadata_url/meta-data/instance-id")
    availability_zone=$(curl -fsS --noproxy '*' --max-time 5 --retry 3 \
      -H "X-aws-ec2-metadata-token: $token" "$metadata_url/meta-data/placement/availability-zone")

    # Pass the project name as data so Bash cannot interpret it as code.
    project_name=$(printf '%s' '${base64encode(local.project_name_html)}' | base64 --decode)

    cat > /usr/share/nginx/html/index.html <<HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>$project_name</title>
      <style>
        body { margin: 0; background: #f1f5f9; color: #0f172a; font: 1rem/1.5 system-ui, sans-serif; }
        main { max-width: 36rem; margin: 4rem auto; padding: 2rem; background: white; border-radius: 1rem; }
        h1 { margin-top: 0; }
        dt { margin-top: 1rem; font-weight: 600; }
        dd { margin: 0; overflow-wrap: anywhere; }
      </style>
    </head>
    <body>
      <main>
        <h1>$project_name</h1>
        <dl>
          <dt>Instance ID</dt>
          <dd>$instance_id</dd>
          <dt>Availability Zone</dt>
          <dd>$availability_zone</dd>
        </dl>
      </main>
    </body>
    </html>
    HTML

    systemctl enable --now nginx
  USER_DATA
  )
}
