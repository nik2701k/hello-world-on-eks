# All AWS calls go through the `project` profile ONLY (hard rule for this assignment),
# pinned to ap-south-1.
provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "hello-world-on-eks"
      ManagedBy = "terraform"
      Phase     = "1-eks"
    }
  }
}
