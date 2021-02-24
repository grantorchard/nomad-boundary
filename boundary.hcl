job "boundary" {
  datacenters = ["humblelabvm"]
  type = "service"

  group "database" {
    count = 1
		network {
			mode = "bridge"
			port "postgres" {
				static = 5432
			}
		}

		task "postgres" {
      driver = "docker"
      config {
        image = "postgres"
        ports = ["postgres"]
      }
      env {
				POSTGRES_USER="postgres"
				POSTGRES_PASSWORD="Hashi123!"
				POSTGRES_DB="boundary"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 1000
        memory = 1024
      }

      service {
        name = "boundary-postgres"
        tags = ["postgres", "boundary"]
        port = "postgres"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
		}
		task "database-init" {
			vault {
        policies = ["boundary"]
			}
			lifecycle {
				hook = "poststart"
				sidecar = "false"
			}
			artifact {
				source      = "https://raw.githubusercontent.com/grantorchard/boundary-configs/main/init.hcl.tpl"
			}
			template {
				source        = "local/init.hcl.tpl"
				destination   = "local/init.hcl"
			}
			driver = "docker"
			env {
				BOUNDARY_POSTGRES_URL="postgresql://postgres:Hashi123!@boundary-postgres.consul?sslmode=disable"
			}
			config {
				image   = "hashicorp/boundary"
				mounts = [
					{
						type   = "bind"
						source = "local"
						target = "/etc/boundary.d"
					}
				]
				args    = [
					"database",
					"init",
					"-config",
					"/etc/boundary.d/init.hcl"
				]
			}

		}
		restart {
			attempts = 30
			interval = "10m"
			delay = "5s"
			mode = "delay"
		}
	}

	group "controller" {
		count = 1
			network {
				mode = "bridge"
				port "boundary-controller" {
					static = 9200
				}
			}
		task "controller" {
			vault {
				policies = ["boundary"]
			}
			artifact {
					source      = "https://raw.githubusercontent.com/grantorchard/boundary-configs/main/controller.hcl.tpl"
				}
			template {
				source        = "local/controller.hcl.tpl"
				destination   = "local/controller.hcl"
			}
			driver = "docker"
			config {
				image   = "hashicorp/boundary"
				ports = ["boundary-controller"]
				mounts = [
					{
						type   = "bind"
						source = "local"
						target = "/etc/boundary.d"
					}
				]
				args    = [
					"server",
					"-config",
					"/etc/boundary.d/controller.hcl"
				]
			}

			env {
				BOUNDARY_POSTGRES_URL="postgresql://postgres:Hashi123!@boundary-postgres.consul?sslmode=disable"
			}

			logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 1000
        memory = 1024
      }

			service {
        name = "boundary-controller"
        tags = ["controller", "boundary"]
        port = "boundary-controller"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
			restart {
				attempts = 30
				interval = "10m"
				delay = "5s"
				mode = "delay"
			}
		}
	}
}
