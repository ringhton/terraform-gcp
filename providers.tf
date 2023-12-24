terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    aws = {
      source = "hashicorp/aws"
    }
    local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = file(var.key)
  folder_id = var.folder_id
  cloud_id = var.cloud_id
}

provider "aws" {
  region = var.reg_aws
  access_key = var.acs_key
  secret_key = var.sec_key
}
