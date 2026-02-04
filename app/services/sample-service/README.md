Sample microservice for Introspect 2B

- Flask app listening on port 8080
- Dockerfile provided
- Deployable via Helm chart in this folder

Build locally:
  docker build -t sample-service:latest .

Run locally:
  docker run -p 8080:8080 sample-service:latest

Helm install (with kubectl configured):
  helm upgrade --install sample-service ./ --namespace default

Bedrock configuration (local testing) 🔧

Set up environment variables to test Bedrock integration locally. By default the service will prefer an AWS profile if present, or fall back to IAM role credentials on EKS/EC2:

- BEDROCK_MODEL_ID: (required) model id to invoke in Bedrock
- BEDROCK_AUTH_MODE: optional; one of `auto` (default), `profile`, `role`
- AWS_PROFILE: optional; when using `profile` mode (or auto with profile present), the AWS profile name (defaults to `Deepak` if omitted)
- AWS_REGION: AWS region (defaults to `us-east-1`)

Examples:

Use a local profile named `Deepak`:

  export AWS_PROFILE=Deepak
  export BEDROCK_MODEL_ID=my-bedrock-model
  python -m flask run --port 8080

Force role-based auth (useful when running in EKS with IRSA/instance role):

  export BEDROCK_AUTH_MODE=role
  export BEDROCK_MODEL_ID=my-bedrock-model
  python -m flask run --port 8080

Endpoint to test:

  curl -X POST http://localhost:8080/claims/1001/summarize

Helm & IRSA example 🔒

If you provisioned the `bedrock` IAM role via Terraform using `infra/modules/iam`, you can attach the role ARN to the service account when installing via Helm. Example (replace <role-arn> with the Terraform output):

  helm upgrade --install sample-service ./ --namespace default \
    --set serviceAccount.annotations."eks.amazonaws.com/role-arn"="<role-arn>" \
    --set bedrock.modelId="<your-bedrock-model-id>"

Alternatively, you can create the service account and annotate it using `kubectl` after applying the Helm chart (if the chart created the SA without the annotation):

  kubectl annotate serviceaccount sample-service-<release-name> \
    -n default eks.amazonaws.com/role-arn="<role-arn>"

Notes:
- Ensure the role ARN matches the role created by `infra/modules/iam`.
- Use `BEDROCK_AUTH_MODE=role` when running in-cluster with an IRSA-bound SA.
