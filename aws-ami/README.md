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
1. Install Packer, a tool for building AMIs
```bash
# Install Packer using Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/packer
# Verify the installation
packer --version
```
1. Configure AWS credentials
```bash
# You will be prompted to enter your AWS Access Key ID, Secret Access Key, and default region.
aws configure
```

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

