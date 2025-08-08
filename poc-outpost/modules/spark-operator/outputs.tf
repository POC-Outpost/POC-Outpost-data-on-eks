output "s3_bucket_id_spark_history_server" {
  description = "Spark History server logs S3 bucket ID"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_team_bucket_info" {
  description = "Spark team bucket information"
  value = {
    for team, bucket in module.s3_bucket_data_team :
    team => {
      name = bucket.s3_bucket_name
      id   = bucket.s3_bucket_id
    }
  }
}