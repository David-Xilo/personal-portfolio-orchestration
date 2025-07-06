
# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# so cloud run can access private networks
resource "google_project_service" "vpcaccess_api" {
  service = "vpcaccess.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_compute_network" "vpc" {
  name                    = "safehouse-vpc"
  auto_create_subnetworks = false
  depends_on             = [google_project_service.compute_api]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "safehouse-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Private service connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  depends_on             = [google_project_service.servicenetworking_api]
}

# Firewall rules for enhanced security
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "deny-all-ingress"
  network = google_compute_network.vpc.name

  deny {
    protocol = "all"
  }

  direction = "INGRESS"
  priority  = 65534
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-communication"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"
  priority  = 1000
  source_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_cloud_sql" {
  name    = "allow-cloud-sql"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  direction = "INGRESS"
  priority  = 1000
  source_ranges = [
    "10.0.0.0/24",     # subnet
    "10.8.0.0/28"      # VPC connector
  ]
  target_tags = ["cloud-sql"]
}

resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  direction = "INGRESS"
  priority  = 1000
  source_ranges = [
    "130.211.0.0/22",   # Google health check ranges
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22"
  ]
}

resource "google_compute_firewall" "deny_egress_internet" {
  name    = "deny-egress-internet"
  network = google_compute_network.vpc.name

  deny {
    protocol = "all"
  }

  direction = "EGRESS"
  priority  = 65534
  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress_internal" {
  name    = "allow-egress-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  direction = "EGRESS"
  priority  = 1000
  destination_ranges = ["10.0.0.0/8"]
}

resource "google_compute_firewall" "allow_egress_google_apis" {
  name    = "allow-egress-google-apis"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  direction = "EGRESS"
  priority  = 1000
  destination_ranges = [
    "199.36.153.8/30", # google apis
    "199.36.153.4/30"
  ]
}

# Cloud NAT for secure outbound internet access
resource "google_compute_router" "router" {
  name    = "safehouse-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "safehouse-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# VPC Access Connector for Cloud Run to reach private resources
resource "google_vpc_access_connector" "connector" {
  name          = "safehouse-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  region        = var.region
  depends_on    = [google_project_service.vpcaccess_api]
}
