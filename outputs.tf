output "minecraft_server_ip" {
  description = "The public IP address of the Minecraft server"
  value       = yandex_compute_instance.minecraft.network_interface[0].nat_ip_address
}

output "minecraft_server_port" {
  description = "The port of the Minecraft server"
  value       = "25565"
}
