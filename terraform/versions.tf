terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.79, < 6.0"
    }
  }

  # Local state for this throwaway 5-day assignment (see README for the S3+DynamoDB
  # alternative). No backend block => state lives in ./terraform.tfstate (gitignored).
}
