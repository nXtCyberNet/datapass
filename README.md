# AWS Serverless News Aggregation & Summarization Pipeline

## Overview

This project is a **serverless data pipeline** that automatically fetches daily news articles, stores them in an S3 data lake, and generates **AI-powered summaries**.

It uses **AWS Lambda (Docker-based)** for compute, **Terraform** for infrastructure, and **GitHub Actions** for CI/CD automation.

---

## Architecture

### 1. Scheduling

* **Amazon EventBridge** triggers the ingestion Lambda every **30 minutes**.

### 2. Data Ingestion – `datataker`

* Fetches latest news about **India** from **newsdata.io API**
* Checks existing S3 data to avoid duplicates
* Appends new articles to a **daily JSON log** in `raw_data/`
* Publishes a success message to **Amazon SNS**

### 3. Processing & Summarization – `summery`

* Triggered automatically by **SNS**
* Reads updated JSON data from S3
* Extracts the **last 3 articles**
* Sends content to **Gemini-2.5-Flash** using **g4f**
* Stores the generated summary in `summaries/` in S3

---

## Project Structure

```bash
.
├── .github/workflows/
│   └── main.yml           # CI/CD pipeline (build & deploy Lambdas)
├── lamda/
│   ├── datataker/         # News ingestion service
│   │   ├── main.py
│   │   ├── Dockerfile
│   │   └── requirement.txt
│   └── summery/           # News summarization service
│       ├── summery.py
│       ├── Dockerfile
│       └── requirement.txt
└── terraform/             # Infrastructure as Code
    ├── main.tf            # IAM, Lambda, SNS, S3, ECR
    ├── provider.tf        # Providers
    ├── vpc.tf             # VPC, Subnets, NAT, Routes
    ├── veriable.tf        # Variables
    └── ...
```

---

## Prerequisites

* AWS account with permissions for:

  * VPC, IAM, Lambda, S3, SNS, ECR
* **Terraform** installed
* **Docker** installed and running
* **AWS CLI** configured locally
* **NewsData.io API Key**

---

## Infrastructure Setup (Terraform)

```bash
cd terraform
terraform init
terraform plan
terraform apply --auto-approve
```

> ⚠️ Terraform uses `local-exec` to build and push Docker images to **ECR**. Docker must be running and AWS CLI must be authenticated.

---

## Configuration

### Environment Variables

| Variable        | Description                                    |
| --------------- | ---------------------------------------------- |
| `API_KEY`       | NewsData.io API key (required for `datataker`) |
| `BUCKET_NAME`   | Auto-created by Terraform                      |
| `SNS_TOPIC_ARN` | Auto-created by Terraform                      |

⚠️ **Important**: `API_KEY` is **not injected by Terraform**. You must:

* Add it manually in AWS Lambda console, **or**
* Update `terraform/main.tf` to include it in the Lambda `environment` block.

---

## CI/CD Deployment

GitHub Actions workflow automatically builds and deploys Lambdas on every push to `main`.

### Required GitHub Secrets

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`
* `ECR_REPOSITORY1` – datataker repo name
* `ECR_REPOSITORY2` – summery repo name
* `LAMBDA_FUNCTION_NAME1` – datataker Lambda name
* `LAMBDA_FUNCTION_NAME2` – summery Lambda name

---

## Networking & Security

* Lambdas run inside a **private subnet** (no public IPs)
* **NAT Gateway** allows outbound internet access only
* **S3 Gateway Endpoint** keeps S3 traffic inside AWS network

This design ensures **zero inbound access** and strong isolation.

---

## Tech Stack

* **Language**: Python 3.12
* **Infrastructure**: Terraform
* **Containerization**: Docker
* **Compute**: AWS Lambda, EventBridge
* **Storage & Messaging**: Amazon S3, Amazon SNS
* **AI / LLM**: g4f (Gemini-2.5-Flash)

---

## Future Improvements

* Secrets Manager for API keys
* Dead-letter queues (DLQ) for Lambda failures
* Structured logs with CloudWatch Insights
* Cost monitoring & alerts

---

## License

MIT License
