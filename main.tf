terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

variable "app_id" {
  type        = string
  default     = "ollama"
  description = "Unique identifier for this app instance (user-defined, freeform)"
}

variable "network_name" {
  type        = string
  description = "Pre-created Docker network name for this app (managed by zeropoint)"
}

variable "arch" {
  type        = string
  default     = "amd64"
  description = "Target architecture - amd64, arm64, etc. (injected by zeropoint)"
}

variable "gpu_vendor" {
  type        = string
  default     = ""
  description = "GPU vendor - nvidia, amd, intel, or empty for no GPU (injected by zeropoint)"
}

# Build Ollama image from local Dockerfile
resource "docker_image" "ollama" {
  name = "${var.app_id}:latest"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
    platform   = "linux/${var.arch}"  # Uses injected arch variable
  }
  keep_locally = true
}

# Main Ollama container (no host port binding)
resource "docker_container" "ollama_main" {
  name  = "${var.app_id}-main"
  image = docker_image.ollama.image_id

  # Network configuration (provided by zeropoint)
  networks_advanced {
    name = var.network_name
  }

  # Restart policy
  restart = "unless-stopped"

  # GPU access (conditional based on vendor)
  runtime = var.gpu_vendor == "nvidia" ? "nvidia" : null
  gpus    = var.gpu_vendor != "" ? "all" : null

  # Environment variables
  env = [
    "OLLAMA_HOST=0.0.0.0",
  ]

  # Ports exposed internally (no host binding)
  # Port 11434 is accessible via service discovery (DNS)
}

# Outputs for zeropoint (container resource only)
output "main" {
  value       = docker_container.ollama_main
  description = "Main Ollama container"
}