# Project 1 · AWS Highly Available Web Infrastructure Using Terraform

## Project Overview & Key Objectives

This project deploys a highly available Nginx web tier in AWS `us-east-1` using Terraform. An internet-facing Application Load Balancer (ALB) sends HTTP traffic to healthy EC2 instances across two Availability Zones. The web page displays the project name, instance ID, and Availability Zone so requests can be traced to the serving instance.

- Define a repeatable network and web tier with Terraform.
- Keep the application available during a single-instance failure using ALB health checks and Auto Scaling.
- Manage instances through AWS Systems Manager Session Manager with SSH closed.
- Monitor CPU utilization, request volume, and target health with CloudWatch.

## Architecture Diagram

```mermaid
graph TD
    Internet["Internet"] -->|HTTP port 80| ALB
    subgraph VPC["VPC · 10.0.0.0/16 · us-east-1"]
        subgraph Public["Public subnets · us-east-1a and us-east-1b"]
            ALB["Internet-facing Application Load Balancer"]
            TG["HTTP target group · health check /"]
            subgraph ASG["Auto Scaling group · min 2, desired 2, max 3"]
                EC2A["us-east-1a · EC2 t3.micro<br/>Amazon Linux 2023 · Nginx · IMDSv2"]
                EC2B["us-east-1b · EC2 t3.micro<br/>Amazon Linux 2023 · Nginx · IMDSv2"]
            end
            ALB --> TG
            TG --> EC2A
            TG --> EC2B
        end
        subgraph Private["Private subnets · reserved for a future DB tier"]
            DBA["Private subnet · us-east-1a"]
            DBB["Private subnet · us-east-1b"]
        end
    end
    IAM["EC2 IAM role and instance profile"] -.-> EC2A
    IAM -.-> EC2B
    SSM["AWS Systems Manager Session Manager"]
    EC2A -.->|Outbound HTTPS| SSM
    EC2B -.->|Outbound HTTPS| SSM
    EC2A -.->|CPU metrics| CW["CloudWatch · 2 alarms and 1 dashboard"]
    EC2B -.->|CPU metrics| CW
    ALB -.->|Requests and target health| CW
```

The public subnets share a route table with a default route through the internet gateway. The private subnets use local VPC routing and are reserved for a future database tier.

## Security Best Practices Implemented

| Control | Implementation |
| --- | --- |
| Zero SSH | Port 22 is closed. Administrative sessions use AWS Systems Manager Session Manager with the EC2 instance profile and its `AmazonSSMManagedInstanceCore` policy. |
| Security group chaining | The public ALB accepts HTTP on port 80. The EC2 security group accepts HTTP on port 80 only from the ALB security group. |
| IMDSv2 | The launch template requires metadata tokens. The bootstrap script uses a token to retrieve the instance ID and Availability Zone. |
| Dedicated Terraform identity | Use a dedicated IAM user for Terraform with scoped permissions and credentials stored outside the repository. AWS account root access keys are excluded from the deployment workflow. |

## Verification & Failure Simulation Results

| Test | Observed result |
| --- | --- |
| Multi-AZ load balancing | Requests through the ALB returned pages identifying instances in both `us-east-1a` and `us-east-1b`. |
| Direct EC2 access | An HTTP request to an EC2 public IP timed out while the ALB URL remained reachable, demonstrating the security group restriction. |
| Auto Scaling self-healing | After one EC2 instance was terminated, the ASG detected the loss and automatically launched a replacement. The ALB continued serving requests through the remaining healthy instance, with zero downtime observed during the test. |

## Observability & Cost Optimization

- **CloudWatch alarms** track average ASG CPU utilization above 70% for two consecutive 120-second periods and average ALB `UnHealthyHostCount` above zero for one 60-second period.
- **CloudWatch dashboard** shows average EC2 CPU utilization for the ASG, total ALB requests, and healthy and unhealthy target counts.
- **CPU monitoring interval** matters for the alarm. EC2 basic monitoring publishes CPU data every five minutes, so the dashboard uses a 300-second period and the 120-second alarm can show `INSUFFICIENT_DATA`. [AWS EC2 monitoring documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/manage-detailed-monitoring.html)
- **Cost controls** include `t3.micro` instances with standard CPU credits, a maximum of three instances, two alarms, and one dashboard. The design omits NAT Gateway and interface VPC endpoints. Check your account’s Free Tier eligibility and usage because EC2, storage, the ALB, and public IPv4 addresses can incur charges. Run `terraform destroy` after the demo to remove Terraform-managed resources. [AWS Free Tier](https://aws.amazon.com/free/) · [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)

## Screenshots

| Network and security | Availability and monitoring |
| --- | --- |
| ![VPC resource map](./screenshots/02-vpc-resource-map.png.jpg) | ![ALB target group with healthy instances](./screenshots/03-alb-target-group-healthy.png.jpg) |
| ![Web page served from us-east-1a](./screenshots/04-webapp-az-a.png.jpg) | ![Web page served from us-east-1b](./screenshots/05-webapp-az-b.png.jpg) |
| ![Direct HTTP request to the EC2 public IP timing out](./screenshots/06-security-group-chaining-proof.png.jpg) | ![Auto Scaling activity showing instance replacement](./screenshots/07-asg-self-healing-activity.png.jpg) |
| ![CloudWatch alarm list](./screenshots/08-cloudwatch-alarms.png.jpg) | ![CloudWatch monitoring dashboard](./screenshots/09-cloudwatch-dashboard.png.jpg) |

## How to Deploy & Destroy

Install Terraform 1.5 or later and configure AWS credentials for the dedicated Terraform IAM user. Run the commands from the directory containing this README and the Terraform files. The configuration defaults to `us-east-1`.

```sh
terraform init
terraform plan
```

Review the plan, then deploy and print the application URL.

```sh
terraform apply
terraform output -raw alb_url
```

Open the URL once the target group reports healthy instances. Check the instance ID and Availability Zone displayed on the page.

When the demo is finished, review and confirm the teardown from the same directory.

```sh
terraform destroy
```
