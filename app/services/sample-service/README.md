Sample microservice for Introspect 2B

- Flask app listening on port 8080
- Dockerfile provided
- Deployable via Helm chart in this folder

Build locally:
  docker build -t sample-service:latest .

Run locally:
  docker run -p 8080:8080 sample-service:latest

Helm install (with repo EKS/kubectl configured):
  helm install sample-service ./ --namespace default
