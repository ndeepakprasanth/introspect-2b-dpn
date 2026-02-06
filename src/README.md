# Source Code

The application source code is located in `app/services/sample-service/`.

This directory serves as a reference pointer for the lab deliverable structure.

## Structure
- `app.py` - Flask application with claim status and summarization endpoints
- `bedrock_client.py` - Amazon Bedrock integration for GenAI summarization
- `bedrock_stub.py` - Local stub for testing without Bedrock
- `Dockerfile` - Container image definition
- `requirements.txt` - Python dependencies
- `Chart.yaml` & `values.yaml` - Helm chart for Kubernetes deployment
- `templates/` - Kubernetes manifests

## Key Endpoints

### GET /claims/{id}
Returns claim status from DynamoDB (currently using mock data).

### POST /claims/{id}/summarize
Invokes Amazon Bedrock to generate:
- Overall summary
- Customer-facing summary
- Adjuster-focused summary
- Recommended next step

## Running Locally
```bash
cd app/services/sample-service
pip install -r requirements.txt
python app.py
```

## Building Container
```bash
docker build -t introspect-sample-service:latest app/services/sample-service
```
