# Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Internet                                    │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ HTTPS
                                 ▼
                    ┌────────────────────────┐
                    │   Amazon API Gateway   │
                    │    (HTTP API)          │
                    │  - GET /claims/{id}    │
                    │  - POST /claims/{id}/  │
                    │    summarize           │
                    └────────────┬───────────┘
                                 │
                                 │ VPC Link
                                 ▼
┌────────────────────────────────────────────────────────────────────────┐
│                              AWS VPC                                    │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Private Subnets                                │  │
│  │  ┌────────────────────────┐                                       │  │
│  │  │  Network Load Balancer │                                       │  │
│  │  │    (Internal)          │                                       │  │
│  │  └──────────┬─────────────┘                                       │  │
│  │             │                                                      │  │
│  │             │ TCP:8080                                            │  │
│  │             ▼                                                      │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │              Amazon EKS Cluster                              │ │  │
│  │  │  ┌────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  EC2 Worker Nodes (t3.small)                           │ │ │  │
│  │  │  │  ┌──────────────────────────────────────────────────┐  │ │ │  │
│  │  │  │  │  Pod: sample-service                             │  │ │ │  │
│  │  │  │  │  ┌────────────────────────────────────────────┐  │  │ │ │  │
│  │  │  │  │  │  Container: Flask App                      │  │  │ │ │  │
│  │  │  │  │  │  - GET /claims/{id}                        │  │  │ │ │  │
│  │  │  │  │  │  - POST /claims/{id}/summarize             │  │  │ │ │  │
│  │  │  │  │  │  - Bedrock Client                          │  │  │ │ │  │
│  │  │  │  │  └────────────────────────────────────────────┘  │  │ │ │  │
│  │  │  │  │  ServiceAccount: sample-service (IRSA)          │  │ │ │  │
│  │  │  │  └──────────────────────────────────────────────────┘  │ │ │  │
│  │  │  └────────────────────────────────────────────────────────┘ │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ AWS SDK (IRSA)
                                 ▼
                    ┌────────────────────────┐
                    │   Amazon Bedrock       │
                    │   (Claude 3 Sonnet)    │
                    │   - Text Summarization │
                    │   - Recommendations    │
                    └────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         Data & Storage Layer                             │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  Amazon ECR      │  │  Amazon S3       │  │  Amazon DynamoDB     │  │
│  │  - Container     │  │  - Claim Notes   │  │  - Claim Status      │  │
│  │    Images        │  │  - Mock Data     │  │  - Mock Data         │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         Security & Monitoring                            │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │ Amazon Inspector │  │ AWS Security Hub │  │ Amazon CloudWatch    │  │
│  │ - ECR Scanning   │  │ - Findings       │  │ - Logs               │  │
│  │ - Vulnerabilities│  │ - Compliance     │  │ - Metrics            │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              CI/CD Pipeline                              │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  GitHub          │  │  AWS CodeBuild   │  │  AWS CodePipeline    │  │
│  │  - Source Code   │  │  - Build         │  │  - Orchestration     │  │
│  │  - GitHub Actions│  │  - Test          │  │  - Deployment        │  │
│  │                  │  │  - Push to ECR   │  │                      │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Request Flow

### GET /claims/{id}

```
User → API Gateway → VPC Link → NLB → EKS Pod → DynamoDB
                                              ↓
                                         Response
```

### POST /claims/{id}/summarize

```
User → API Gateway → VPC Link → NLB → EKS Pod → S3 (get notes)
                                              ↓
                                         Bedrock (summarize)
                                              ↓
                                         Response
```

## Security Flow (IRSA)

```
EKS Pod (ServiceAccount)
    ↓
OIDC Provider
    ↓
IAM Role (AssumeRoleWithWebIdentity)
    ↓
Bedrock Policy (InvokeModel)
    ↓
Amazon Bedrock
```

## CI/CD Flow

```
Developer → Git Push → GitHub
                         ↓
                    GitHub Actions
                         ↓
                    Terraform Apply
                         ↓
                    Infrastructure Created
                         ↓
                    CodeBuild Triggered
                         ↓
                    Build & Test
                         ↓
                    Push to ECR → Inspector Scan
                         ↓
                    Deploy to EKS (Helm)
                         ↓
                    Verify Deployment
```

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Public Subnets (10.0.0.0/24, 10.0.1.0/24)                 │ │
│  │  - Internet Gateway                                         │ │
│  │  - NAT Gateway (future)                                     │ │
│  │  - EC2 Worker Nodes                                         │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Private Subnets (10.0.2.0/24, 10.0.3.0/24)                │ │
│  │  - EKS Control Plane ENIs                                   │ │
│  │  - Internal NLB                                             │ │
│  │  - VPC Link ENIs                                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## IAM Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         IAM Roles                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  EKS Cluster Role                                                │
│  └─ AmazonEKSClusterPolicy                                       │
│                                                                  │
│  EKS Node Role                                                   │
│  ├─ AmazonEKSWorkerNodePolicy                                    │
│  ├─ AmazonEKS_CNI_Policy                                         │
│  └─ AmazonEC2ContainerRegistryReadOnly                           │
│                                                                  │
│  Bedrock Service Account Role (IRSA)                             │
│  └─ Custom Bedrock Invoke Policy                                 │
│     ├─ bedrock:InvokeModel                                       │
│     ├─ bedrock:InvokeModelWithResponseStream                     │
│     └─ bedrock:GetModel                                          │
│                                                                  │
│  CodeBuild Role                                                  │
│  ├─ ECR Push                                                     │
│  ├─ EKS Describe                                                 │
│  └─ S3 Access                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Module Dependencies

```
vpc
 ├─ eks
 │   ├─ node_group
 │   └─ iam (bedrock)
 ├─ nlb
 │   └─ api-gateway
 └─ security_group

ecr
s3
dynamodb
observability
security
pipeline
```

## Deployment Sequence

```
1. VPC & Networking
   └─ Subnets, IGW, Route Tables

2. EKS Cluster
   └─ Control Plane, OIDC Provider

3. Node Group
   └─ EC2 Instances, Auto Scaling

4. Data Stores
   ├─ ECR Repository
   ├─ S3 Bucket
   └─ DynamoDB Table

5. IAM Roles
   └─ IRSA for Bedrock

6. Load Balancing
   ├─ NLB
   └─ Target Groups

7. API Gateway
   ├─ VPC Link
   └─ Routes

8. Security
   ├─ Inspector
   └─ Security Hub

9. Observability
   ├─ Log Groups
   └─ Dashboard

10. Application
    ├─ Build Image
    ├─ Push to ECR
    └─ Deploy via Helm
```

## Cost Breakdown (Estimated Monthly)

```
┌─────────────────────────────────────────────────────────┐
│ Service                    │ Cost/Month                  │
├────────────────────────────┼─────────────────────────────┤
│ EKS Control Plane          │ $73.00                      │
│ EC2 t3.small (1 node)      │ $15.00                      │
│ NLB                        │ $16.00                      │
│ API Gateway                │ $3.50 (1M requests)         │
│ ECR Storage                │ $1.00 (10GB)                │
│ S3 Storage                 │ $0.50 (20GB)                │
│ DynamoDB                   │ $1.00 (on-demand)           │
│ CloudWatch Logs            │ $5.00 (5GB)                 │
│ Bedrock                    │ $10.00 (varies by usage)    │
│ Data Transfer              │ $5.00                       │
├────────────────────────────┼─────────────────────────────┤
│ Total                      │ ~$130/month                 │
└─────────────────────────────────────────────────────────┘

Note: Costs vary based on usage and region
```

## Scalability

```
Current Setup:
- 1 EKS node (t3.small)
- 1 pod replica
- 1 NLB

Scaling Options:
- Horizontal Pod Autoscaling (HPA)
- Cluster Autoscaler for nodes
- Multiple pod replicas
- Larger instance types
- Multi-AZ deployment
```

## High Availability

```
Current: Single AZ (dev)
Production Recommendations:
- Multi-AZ deployment (2-3 AZs)
- Multiple node groups
- Pod anti-affinity rules
- NLB cross-zone load balancing
- RDS for persistent data (vs DynamoDB)
```
