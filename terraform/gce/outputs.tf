output "vm_name" {
  description = "Name of the GCE VM"
  value       = google_compute_instance.vm.name
}

output "public_ip" {
  description = "Static external IP address of the GCE VM"
  value       = google_compute_address.static_ip.address
}

output "app_url" {
  description = "HTTP endpoint for the Spring AI application"
  value       = "http://${google_compute_address.static_ip.address}:${var.app_port}"
}

output "ssh_command" {
  description = "gcloud command to SSH into the VM"
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone ${var.zone} --project ${var.project_id}"
}
