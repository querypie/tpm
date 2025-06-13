# How to build an AMI for AWS Marketplace

## Prepare the build environment

Suppose you are building on macOS.

1. Install AWS CLI
    ```bash
    # Install AWS CLI using Homebrew
    brew install awscli
    # Verify the installation
    aws --version
    ```
2. Configure AWS credentials
    ```bash
    # You will be prompted to enter your AWS Access Key ID, Secret Access Key, and default region.
    aws configure
    ```
3. Give your IAM user permissions to create AMIs by attaching the following policy:
    - AmazonEC2FullAccess
        - ec2:DescribeImages
        - ec2:CreateImage
        - ec2:DescribeKeyPairs
        - ...
4. Install Packer, a tool for building AMIs
    ```bash
    # Install Packer using Homebrew
    brew tap hashicorp/tap
    brew install hashicorp/tap/packer
    # Verify the installation
    packer --version
    ```
5. Initialize the Packer project, which will download the necessary plugins and dependencies
    ```bash
    packer init querypie-ami.pkr.hcl
    ```
6. Modify docker-config.json by populating the auth value.
    ```json
   {
     "auths": {
       "harbor.chequer.io": {
         "auth": "<base64-encoded-username:password>"
       }
     }
   }
    ```
   To generate the auth value, run: `echo -n 'username:password' | base64`

## Build an AMI

Run `build-ami.sh <version>` to build an AMI where <version> is a version of QueryPie.
`./build-ami.sh 10.3.0`

## Troubleshooting

### An error occurred (UnauthorizedOperation) when calling the DescribeImages operation

You may encounter the following error when running Packer:

```
An error occurred (UnauthorizedOperation) when calling the DescribeImages operation: 
  You are not authorized to perform this operation. 
  User: arn:aws:iam::142600000000:user/<USERNAME> is not authorized to perform: 
    ec2:DescribeImages because no identity-based policy allows the ec2:DescribeImages action
```

This error indicates that your IAM user does not have the necessary permissions to describe images.
To resolve this, you need to attach a policy that allows the `ec2:DescribeImages` action to your IAM user.

Steps to resolve the issue:

1. Go to the [IAM Management Console](https://console.aws.amazon.com/iam/home).
2. Select your IAM user.
3. Click on the "Add permissions" button.
4. Choose "Attach policies directly".
5. Search for the `AmazonEC2ReadOnlyAccess` policy and select it.
6. Click on the "Next: Review" button, then click "Add permissions".
7. Wait for a few minutes for the changes to take effect.
8. Retry running the Packer command.

