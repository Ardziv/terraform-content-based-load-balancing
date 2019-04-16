output "self_link" {
    value = "${google_storage_bucket.bucket.self_link}"
}
output "url" {
    value = "${google_storage_bucket.bucket.url}"
}
output "application_public_ip" {
  value = "${google_compute_global_forwarding_rule.default.ip_address}"
}
