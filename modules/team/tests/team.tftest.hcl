mock_provider "aws" {}

variables {
  prefix      = "acme"
  team_name   = "payments"
  cost_center = "CC-1042"
  buckets = [
    { name = "invoices", visibility = "private" },
    { name = "website", visibility = "public" },
  ]
}

run "bucket_names_follow_convention" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this["invoices"].bucket == "acme-payments-invoices"
    error_message = "Bucket name must be <prefix>-<team>-<bucket>."
  }
}

run "private_bucket_blocks_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this["invoices"].block_public_policy == true
    error_message = "Private buckets must block public policies."
  }

  assert {
    condition     = !contains(keys(aws_s3_bucket_policy.public_read), "invoices")
    error_message = "Private buckets must not get a public policy."
  }
}

run "public_bucket_gets_read_only_policy" {
  command = plan

  assert {
    condition     = contains(keys(aws_s3_bucket_policy.public_read), "website")
    error_message = "Public buckets must get the public read policy."
  }
}

run "role_can_only_reach_own_buckets" {
  command = plan

  assert {
    condition = jsondecode(aws_iam_role_policy.this.policy).Statement[1].Resource == [
      "arn:aws:s3:::acme-payments-invoices/*",
      "arn:aws:s3:::acme-payments-website/*",
    ]
    error_message = "The role may only access this team's own buckets."
  }
}

run "rejects_missing_or_wrong_visibility" {
  command = plan

  variables {
    buckets = [{ name = "data", visibility = "internal" }]
  }

  expect_failures = [var.buckets]
}