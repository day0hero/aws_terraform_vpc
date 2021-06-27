# aws_terraform_vpc
Terraform to deploy AWS VPC, Endpoints and Subnets

This module generates a VPC with endpoints, subnets, route-tables and InternetGateways associated with it 
to prepare for the deployment of OCP in an AWS GovCloud environment.

Update the `main.tf` file with the VPC_NAME and CLUSTER_NAME you desire. 

## Using the module:
```
terraform init

terraform plan 

terraform apply 

```

Terraform Version: v0.15.1
