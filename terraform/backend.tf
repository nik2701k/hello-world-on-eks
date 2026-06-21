terraform {
  backend "s3" {
    bucket       = "terraform-state-826784631306"
    key          = "hello-world-eks/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "project"
    encrypt      = true
    use_lockfile = true
  }
}
