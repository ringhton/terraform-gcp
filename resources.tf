data "yandex_vpc_subnet" "foo" {
  name = "default-ru-central1-b"
}

resource "yandex_compute_disk" "default" {
  name     = "disk-vps"
  type     = "network-ssd"
  zone     = "ru-central1-b"
  image_id = "fd8a98m249n8kd88lvo9"
}

resource "yandex_compute_instance" "vps" {
  name        = "virt-vps"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.default.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.foo.id
    nat = true
 }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh)}"
  }

  labels = {
    task_name = var.name
    user_email = var.email
  }
}

data "aws_route53_zone" "selected" {
  name         = "devops.rebrain.srwx.net."
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.id
  name    = "ringhton555"
  type    = "A"
  ttl     = "300"
  records = [
    join(",",flatten(yandex_lb_network_load_balancer.foo1.listener[*].external_address_spec[*].address))
  ]
}

resource "local_file" "ansible_inventory" {
  content  =    templatefile("ansible.tftpl",{
      ansible_connection = "ssh"
      ansible_host_vps = yandex_compute_instance.vps.network_interface.0.nat_ip_address
      ansible_port = 22
      ansible_user = var.user
      ansible_ssh_private_key_file = file(var.priv_key)
      })
  filename = "${path.module}/inventory.yaml"
  provisioner "local-exec"{
    command = "sleep 60 &&  ansible-playbook nginx.yaml;"
  }
}

resource "yandex_compute_disk" "lb" {
  name     = "disk-load"
  type     = "network-ssd"
  zone     = "ru-central1-b"
  image_id = "fd8a98m249n8kd88lvo9"
}

resource "yandex_compute_instance" "lb" {
  name        = "virt-load"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.lb.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.foo.id
    nat = true
 }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh)}"
  }

  labels = {
    task_name = var.name
    user_email = var.email
  }
}

resource "yandex_lb_target_group" "foo1" {
  name      = "my-target-group1"
  region_id = "ru-central1"

  target {
    subnet_id = data.yandex_vpc_subnet.foo.id
    address   = yandex_compute_instance.vps.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "foo1" {
  name = "my-network-load-balancer1"
  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.foo1.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
      }
    }
  }
}
