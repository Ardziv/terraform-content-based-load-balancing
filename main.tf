# https://cloud.google.com/compute/docs/load-balancing/http/content-based-example

provider "google" {
  region      = "${var.region}"
  project     = "${var.project_id}"
  // credentials = "${file("${var.credentials_file_path}")}"
  zone        = "${var.region_zone}"
}

/* INSTANCES (WWW/VIDEO) */
resource "google_compute_instance" "www" {
  name         = "tf-www-compute"
  machine_type = "f1-micro"
  tags         = ["http-tag"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-9"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = "${file("scripts/install-www.sh")}"

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute.readonly"]
  }
}

resource "google_compute_instance" "www-video" {
  name         = "tf-www-video-compute"
  machine_type = "f1-micro"
  tags         = ["http-tag"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-9"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = "${file("scripts/install-video.sh")}"

  service_account {
    scopes = ["https://www.googleapis.com/auth/compute.readonly"]
  }
}
/* INSTANCES (WWW/VIDEO) */

/* GLOBAL ADDRESS (LB IP) */
resource "google_compute_global_address" "external-address" {
  name = "tf-external-address"
}
/* GLOBAL ADDRESS (LB IP) */

/* INSTANCE GROUP */
resource "google_compute_instance_group" "www-resources" {
  name = "tf-www-resources"

  instances = ["${google_compute_instance.www.self_link}"]

  named_port {
    name = "http"
    port = "80"
  }
}

resource "google_compute_instance_group" "video-resources" {
  name = "tf-video-resources"

  instances = ["${google_compute_instance.www-video.self_link}"]

  named_port {
    name = "http"
    port = "80"
  }
}

/* INSTANCE GROUP */

/* HEALTH CHECK */
resource "google_compute_health_check" "health-check" {
  name = "tf-health-check"

  http_health_check {}
}
/* HEALTH CHECK */

/* BACKEND-SERVICES (WWW/VIDEO) */
resource "google_compute_backend_service" "www-service" {
  name     = "tf-www-service"
  protocol = "HTTP"

  backend {
    group = "${google_compute_instance_group.www-resources.self_link}"
  }

  health_checks = ["${google_compute_health_check.health-check.self_link}"]
}

resource "google_compute_backend_service" "video-service" {
  name     = "tf-video-service"
  protocol = "HTTP"

  backend {
    group = "${google_compute_instance_group.video-resources.self_link}"
  }

  health_checks = ["${google_compute_health_check.health-check.self_link}"]
}
/* BACKEND-SERVICES (WWW/VIDEO) */

/* URL-MAP */
resource "google_compute_url_map" "web-map" {
  name            = "tf-web-map"
  default_service = "${google_compute_backend_service.www-service.self_link}"

  host_rule {
    hosts        = ["*"]
    path_matcher = "tf-allpaths"
  }

  path_matcher {
    name            = "tf-allpaths"
    default_service = "${google_compute_backend_service.www-service.self_link}"

    path_rule {
      paths   = ["/video", "/video/*"]
      service = "${google_compute_backend_service.video-service.self_link}"
    }

    path_rule {
      paths   = ["/static", "/static/*"]
      service = "${google_compute_backend_bucket.static_backend.self_link}"
    }
  }
}

/* URL-MAP */

/* FRONTEND & BACKEND BUCKET & ACL */
resource "google_compute_backend_bucket" "static_backend" {
	name = "${var.backend_bucket_name}"
	bucket_name = "${google_storage_bucket.bucket.name}"
	enable_cdn = false
}

resource "google_storage_bucket" "bucket" {
    name = "${var.bucket_name}"
    location = "${var.bucket_location}"
    project = "${var.project_id}"
    storage_class = "${var.bucket_storage_class}"

    versioning {
        enabled = "${var.bucket_versioning}"
    }

    website {
        main_page_suffix = "${var.main_page_suffix}"
        not_found_page = "${var.not_found_page}"
    }
}

resource "google_storage_default_object_acl" "default_obj_acl" {
    bucket = "${google_storage_bucket.bucket.name}"
    role_entity = ["${var.role_entity}"]

}
/* FRONTEND & BACKEND BUCKET & ACL */

/* HTTP PROXY */
resource "google_compute_target_http_proxy" "http-lb-proxy" {
  name    = "tf-http-lb-proxy"
  url_map = "${google_compute_url_map.web-map.self_link}"
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "tf-http-content-gfr"
  target     = "${google_compute_target_http_proxy.http-lb-proxy.self_link}"
  ip_address = "${google_compute_global_address.external-address.address}"
  port_range = "80"
}

data "google_compute_lb_ip_ranges" "ranges" {}

resource "google_compute_firewall" "default" {
  name    = "tf-www-firewall-allow-internal-only"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["${data.google_compute_lb_ip_ranges.ranges.http_ssl_tcp_internal}"] // The IP ranges used for health checks when HTTP(S), SSL proxy, TCP proxy, and Internal load balancing is used
  //source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  //source_ranges = ["${data.google_compute_lb_ip_ranges.ranges.network}"] // FOR NETWORK_LOAD_BALANCER
  target_tags   = ["http-tag"]
}
/* HTTP PROXY */
