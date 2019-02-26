provider "google" {
  project = "${var.gcp_project}"
}

resource "random_id" "instance_id" {
  byte_length = 2
}

locals {
  environment_name = "${var.DESKTOP_ENVIRONMENT_REGISTRY}-${var.DESKTOP_ENVIRONMENT_CONTAINER}-${random_id.instance_id.hex}"
}

resource "google_compute_instance" "desktop-environment" {
  allow_stopping_for_update = true
  machine_type = "${var.machine_type}"
  name = "${local.environment_name}"
  project = "${var.gcp_project}"
  tags = ["${local.environment_name}"]
  zone = "${var.machine_region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-minimal-1810"
      type = "pd-ssd"
      size = "80"
    }
  }

  network_interface {
    access_config {
      nat_ip = "35.201.14.140"
    }
    subnetwork = "${google_compute_subnetwork.desktop-environment.name}"
  }

  labels {
    owner-host = "${replace(lower(var.owner_host), "/[^a-z0-9-_]/", "")}"
    owner-name = "${replace(lower(var.owner_name), "/[^a-z0-9-_]/", "")}"
  }

  provisioner "remote-exec" {

    inline = [
      "# Clone the desktop environment",
      "git clone https://github.com/${var.DESKTOP_ENVIRONMENT_REGISTRY}/${var.DESKTOP_ENVIRONMENT_CONTAINER}",

      "# Start the desktop-environment",
      "${var.DESKTOP_ENVIRONMENT_HOST_REPOSITORY}/host/bootstrap-cloud.sh",
    ]
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
    ]
  }
}

resource "google_compute_firewall" "desktop-environment" {
  name = "${local.environment_name}"
  network = "${google_compute_network.desktop-environment.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    ports = [
      "80",
      "443",
    ]
    protocol = "tcp"
  }

  target_tags = ["${local.environment_name}"]
}

resource "google_compute_subnetwork" "desktop-environment" {
  name = "${local.environment_name}"
  ip_cidr_range = "10.2.0.0/16"
  network = "${google_compute_network.desktop-environment.name}"
  region = "${var.machine_region}"
}

resource "google_compute_network" "desktop-environment" {
  auto_create_subnetworks = false
  name = "${local.environment_name}"
}