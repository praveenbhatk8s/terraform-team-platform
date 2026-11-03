output "role_arn" {
  value = aws_iam_role.this.arn
}

output "bucket_names" {
  value = [for b in aws_s3_bucket.this : b.bucket]
}