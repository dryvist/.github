terraform {
  required_version = ">= 1.6.0"
}

output "canary" {
  description = "Canary fixture output; read by nothing."
  value       = "ok"
}
