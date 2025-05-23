terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = var.zone
}

resource "yandex_vpc_subnet" "minecraft" {
  name           = "minecraft-subnet"
  zone           = var.zone
  network_id     = var.network_id
  v4_cidr_blocks = ["10.0.0.0/24"]
}


resource "yandex_compute_instance" "minecraft" {
  name         = "minecraft-server"
  folder_id    = var.folder_id
  zone         = var.zone

  network_interface {
    subnet_id = yandex_vpc_subnet.minecraft.id
    nat       = true
  }

  resources {
    memory     = 24
    cores      = 12
  }

  boot_disk {
    initialize_params {
      image_id = "fd86601pa1f50ta9dffg"
      type     = "network-ssd"
      size     = "50"
    }
  }


  metadata = {
    ssh-keys = "ubuntu:${file("${path.module}/minecraft-key.pub")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y openjdk-21-jdk",
      "sudo mkdir -p /minecraft-server",
      "sudo chown -R ubuntu:ubuntu /minecraft-server",
      "sudo chmod -R 755 /minecraft-server",
      "sudo wget -O /minecraft-server/server.jar https://piston-data.mojang.com/v1/objects/145ff0858209bcfc164859ba735d4199aafa1eea/server.jar",
      "echo 'eula=true' | sudo tee /minecraft-server/eula.txt",
      "echo '#!/bin/bash\ncd /minecraft-server && java -Xmx2048M -Xms1024M -jar server.jar nogui' | sudo tee /minecraft-server/run.sh",
      "sudo chmod +x /minecraft-server/run.sh",
      "printf '[Unit]\nDescription=Minecraft Server\nAfter=network.target\n\n[Service]\nUser=ubuntu\nWorkingDirectory=/minecraft-server\nExecStart=/minecraft-server/run.sh\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' | sudo tee /etc/systemd/system/minecraft.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable minecraft",
      "sudo systemctl start minecraft",
      "sleep 20",
      "sudo sed -i 's/^online-mode=.*/online-mode=false/' /minecraft-server/server.properties",
      "sudo systemctl restart minecraft"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("${path.module}/minecraft-key")
    host        = self.network_interface.0.nat_ip_address
  }
}

resource "yandex_vpc_security_group" "minecraft" {
  name       = "minecraft-options"
  folder_id  = var.folder_id
  network_id = var.network_id
}

resource "yandex_vpc_security_group_rule" "minecraft_ingress_minecraft" {
  security_group_binding = yandex_vpc_security_group.minecraft.id
  direction               = "ingress"
  protocol                = "TCP"
  port                    = 25565
  v4_cidr_blocks          = ["0.0.0.0/0"]
  description             = "Minecraft"
}

resource "yandex_vpc_security_group_rule" "minecraft_ingress_ssh" {
  security_group_binding = yandex_vpc_security_group.minecraft.id
  direction               = "ingress"
  protocol                = "TCP"
  port                    = 22
  v4_cidr_blocks          = ["0.0.0.0/0"]
  description             = "SSH"
}

resource "yandex_vpc_security_group_rule" "minecraft_egress_all" {
  security_group_binding = yandex_vpc_security_group.minecraft.id
  direction               = "egress"
  protocol                = "ANY"
  v4_cidr_blocks          = ["0.0.0.0/0"]
  description             = "All egress"
}
