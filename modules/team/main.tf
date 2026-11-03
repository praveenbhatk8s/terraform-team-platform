locals {
  # One entry per bucket, keyed by its short name:
  #   invoices = { full_name = "acme-payments-invoices", visibility = "private" }
  buckets = {
    for b in var.buckets : b.name => {
      full_name  = "${var.prefix}-${var.team_name}-${b.name}"
      visibility = b.visibility
    }
  }

  tags = {
    team        = var.team_name
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}

# ---------- Buckets ----------

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket = each.value.full_name
  tags   = merge(local.tags, { visibility = each.value.visibility })
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = each.value.visibility == "private"
  restrict_public_buckets = each.value.visibility == "private"
}

resource "aws_s3_bucket_policy" "public_read" {
  for_each = { for k, b in local.buckets : k => b if b.visibility == "public" }

  bucket = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::${each.value.full_name}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}