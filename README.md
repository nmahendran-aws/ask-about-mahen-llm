Here is a well-formatted README document for your Lambda deployment workflow, designed for clarity and copy-paste use in your repository. Markdown formatting improvements include command explanation, code blocks, and step organization.

***

# Lambda Python Deployment Guide

This guide provides the step-by-step commands to deploy Python code to AWS Lambda.

***

## **1. Install Dependencies**

Use `uv` to install the requirements:

```bash
uv add -r requirements.txt
```

***

## **2. Run Your Deployment Script**

Use `uv` to run your deployment script (edit `deploy.py` as needed):

```bash
uv run deploy.py
```

***

## **3. Prepare Deployment Bucket**

Set a unique name for the deployment S3 bucket and create the bucket:

```bash
DEPLOY_BUCKET="ask-about-mahen-deploy-$(date +%s)"
aws s3 mb s3://$DEPLOY_BUCKET --region $DEFAULT_AWS_REGION
```

***

## **4. Upload Deployment Package**

Copy your Lambda deployment package (e.g., `lambda-deployment.zip`) to S3:

```bash
aws s3 cp lambda-deployment.zip s3://$DEPLOY_BUCKET/ --region $DEFAULT_AWS_REGION
```

***

## **5. Update Lambda Function**

Update your Lambda function code using the package in S3:

```bash
aws lambda update-function-code \
  --function-name ask-me \
  --s3-bucket $DEPLOY_BUCKET \
  --s3-key lambda-deployment.zip \
  --region $DEFAULT_AWS_REGION
```


