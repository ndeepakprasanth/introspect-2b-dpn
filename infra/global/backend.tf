# Local backend for simplicity (suitable for quick iteration).
# Switch to an S3 backend for team usage / CI once you're ready.
terraform {
  backend "local" {}
}
