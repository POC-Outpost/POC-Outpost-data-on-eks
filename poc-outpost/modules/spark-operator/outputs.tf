output "s3_bucket_id_spark_history_server" {
  description = "Spark History server logs S3 bucket ID"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_team_bucket_info" {
  description = "Spark team buckets: data and logs"
  value = {
    for team in keys(module.s3_bucket_data_team) :
    team => {
      data_bucket = {
        name = module.s3_bucket_data_team[team].s3_bucket_name
        id   = module.s3_bucket_data_team[team].s3_bucket_id
      }
      utility_bucket = {
        name = module.s3_bucket_utility_team[team].s3_bucket_name
        id   = module.s3_bucket_utility_team[team].s3_bucket_id
      }
    }
  }
}