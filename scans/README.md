# Security Scanning Documentation

## Amazon Inspector ECR Scanning

Amazon Inspector automatically scans container images pushed to ECR for vulnerabilities.

### Setup
Inspector is enabled via Terraform in `infra/modules/security/main.tf`:
```hcl
resource "aws_inspector2_enabler" "this" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2"]
}
```

### Viewing Findings

1. **AWS Console**:
   - Navigate to Amazon Inspector
   - Select "Container image scanning"
   - Filter by repository: `introspect-sample-service`

2. **AWS CLI**:
```bash
aws inspector2 list-findings \
  --filter-criteria '{"ecrImageRepositoryName":[{"comparison":"EQUALS","value":"introspect-sample-service"}]}' \
  --region us-east-1
```

### Sample Findings Structure
```json
{
  "findings": [
    {
      "severity": "HIGH",
      "title": "CVE-2023-XXXXX",
      "description": "Vulnerability in package XYZ",
      "packageVulnerabilityDetails": {
        "vulnerablePackages": [
          {
            "name": "package-name",
            "version": "1.0.0"
          }
        ]
      },
      "remediation": {
        "recommendation": {
          "text": "Update to version 1.0.1 or later"
        }
      }
    }
  ]
}
```

## AWS Security Hub

Security Hub aggregates findings from Inspector and other AWS security services.

### Viewing Consolidated Findings

1. **AWS Console**:
   - Navigate to AWS Security Hub
   - View "Findings" dashboard
   - Filter by resource: `introspect-sample-service`

2. **AWS CLI**:
```bash
aws securityhub get-findings \
  --filters '{"ResourceId":[{"Value":"introspect-sample-service","Comparison":"CONTAINS"}]}' \
  --region us-east-1
```

### Security Standards Enabled
- AWS Foundational Security Best Practices v1.0.0

## CI/CD Integration

The CodeBuild pipeline automatically triggers Inspector scans on image push:

```yaml
# In pipelines/buildspec.yml
post_build:
  commands:
    - docker push $REPO_URI:$IMAGE_TAG
    # Inspector automatically scans on push
    - echo "Image pushed - Inspector scan initiated"
```

## Remediation Workflow

1. Review findings in Inspector/Security Hub
2. Update vulnerable packages in `requirements.txt` or base image
3. Rebuild and push image
4. Verify new scan shows reduced vulnerabilities

## Screenshots Location

Place screenshots of Inspector and Security Hub findings in this directory:
- `inspector-findings.png` - ECR scan results
- `securityhub-dashboard.png` - Consolidated security view
- `vulnerability-details.png` - Detailed vulnerability information

## Automated Scanning Schedule

Inspector scans occur:
- On every image push to ECR
- Continuous monitoring for new CVEs
- Re-scan every 24 hours for existing images
