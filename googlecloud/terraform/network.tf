
##
# ALL this was removed to keep gcloud in its free tier
##

# resource "google_compute_network" "vpc" {
#   name                    = "safehouse-vpc"
#   auto_create_subnetworks = false
#   depends_on              = [google_project_service.compute_api]
# }
#
# resource "google_compute_subnetwork" "subnet" {
#   name          = "safehouse-subnet"
#   ip_cidr_range = "10.0.0.0/24"
#   region        = var.region
#   network       = google_compute_network.vpc.id
# }
#
# # Private service connection for Cloud SQL
# resource "google_compute_global_address" "private_ip_address" {
#   name          = "private-ip-address"
#   purpose       = "VPC_PEERING"
#   address_type  = "INTERNAL"
#   prefix_length = 16
#   network       = google_compute_network.vpc.id
# }
#
# resource "google_service_networking_connection" "private_vpc_connection" {
#   network                 = google_compute_network.vpc.id
#   service                 = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
#   depends_on              = [google_project_service.servicenetworking_api]
# }
#
# resource "google_compute_firewall" "allow_cloud_sql" {
#   name    = "allow-cloud-sql"
#   network = google_compute_network.vpc.name
#
#   allow {
#     protocol = "tcp"
#     ports    = ["5432"]
#   }
#
#   direction = "INGRESS"
#   priority  = 1000
#   source_ranges = [
#     "10.0.0.0/24", # subnet
#     "10.8.0.0/28"  # VPC connector
#   ]
#   target_tags = ["cloud-sql"]
# }
#
# resource "google_compute_firewall" "allow_egress_google_apis" {
#   name    = "allow-egress-google-apis"
#   network = google_compute_network.vpc.name
#
#   allow {
#     protocol = "tcp"
#     ports    = ["443"]
#   }
#
#   direction = "EGRESS"
#   priority  = 1000
#   destination_ranges = [
#     "199.36.153.8/30", # google apis
#     "199.36.153.4/30"
#   ]
# }
#
# # Cloud NAT for secure outbound internet access
# resource "google_compute_router" "router" {
#   name    = "safehouse-router"
#   region  = var.region
#   network = google_compute_network.vpc.id
# }
#
# resource "google_compute_router_nat" "nat" {
#   name                               = "safehouse-nat"
#   router                             = google_compute_router.router.name
#   region                             = var.region
#   nat_ip_allocate_option             = "AUTO_ONLY"
#   source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#
#   log_config {
#     enable = true
#     filter = "ERRORS_ONLY"
#   }
# }
#
# # VPC Access Connector for Cloud Run to reach private resources
# resource "google_vpc_access_connector" "connector" {
#   name          = "safehouse-connector"
#   ip_cidr_range = "10.8.0.0/28"
#   network       = google_compute_network.vpc.name
#   region        = var.region
#   depends_on    = [google_project_service.vpcaccess_api]
# }
