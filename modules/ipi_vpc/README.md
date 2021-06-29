# AWS VPC for IPI
This module creates a VPC in the AWS GovCloud West Region. See the table below for 
resources that get created. The outcome of this module is a connected VPC ready for
an OpenShift4 IPI installation.

`main.tf` is where we can override some variables to customize the VPC and deployment a little more.

## main.tf variables
| variable | value |
| -------- | ----- |
| vpc_name | enter the name of the vpc |
| cluster_name | enter the name of the openshift cluster (this can also be the vpc_name ) |
| ssh_private_key_path | enter the path of the private to use to attach to the bastion |
| bastion_public_key_name | enter the name of the public key to attach to the bastion |
| bastion_instance_type | `t3.large` |
| bastion_volume_size | `80` |



## bastion config
| software | version | purpose |
| -------- | :-----: | ------- |
| RHEL     | 8       | Bastion Node |
| openshift-install | 4.7 | used to deploy the openshift cluster |
| openshift-client  | 4.7 | used to manage the cluster after install |
| podman | latest | rootless container runtime |
| vim    | latest | because its all I know     |
| git    | latest | all the repos |



## provisioned cloud resources
|    resource      |
| :-----------------: |
| vpc               |
| private_subnets   |
| public_subnets    |
| Internet Gateway  |
| Nat Gateway       |
| ec2_endpoint      |
| elb_endpoint      |
| s3_endpoint       |
| bastion node      |


