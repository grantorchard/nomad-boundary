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
			lifecycle {
				hook = "poststart"
				sidecar = "false"
			}
			artifact {
				source      = "git::https://github.com/grantorchard/boundary-configs"
				destination = "local/boundary"
			}
			template {
				source        = "local/boundary/controller.hcl.tpl"
				destination   = "local/boundary/controller.hcl"
			}
			driver = "docker"
			env {
				BOUNDARY_PG_URL= "postgresql://postgres:Hashi123!@boundary?sslmode=disable"
			}
			config {
				image   = "hashicorp/boundary"
				command = "database init"
				args    = [
					"-config",
					"/local/boundary/controller.hcl"
				]
			}
		}
	}

	group "controllers" {}
	group "workers" {}
	restart {
		attempts = 10
		interval = "5m"
		delay = "25s"
		mode = "delay"
	}
}
