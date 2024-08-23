bucket         = "catbird-ecommerce-terraform-state-nonprod"
key            = "terraform/tfstate"
region         = "us-east-1"
dynamodb_table = "catbird-ecommerce-terraform-state-lock-nonprod"
encrypt        = true
