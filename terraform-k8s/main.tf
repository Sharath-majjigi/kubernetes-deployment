terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.30.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

locals {
  applications = jsondecode(file("${path.module}/applications.json"))
}

resource "kubernetes_deployment" "app" {
  for_each = { for app in local.applications.applications : app.name => app }

  metadata {
    name = each.value.name
    labels = {
      app = each.value.name
    }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }

      spec {
        container {
          name  = each.value.name
          image = each.value.image

          args = each.value.args

          port {
            container_port = each.value.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  for_each = { for app in local.applications.applications : app.name => app }

  metadata {
    name = each.value.name
  }

  spec {
    selector = {
      app = each.value.name
    }

    port {
      port        = each.value.port
      target_port = each.value.port
    }
  }
}

resource "kubernetes_ingress_v1" "app_ingress" {
  metadata {
    name = "app-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "myapp.local"

      http {
        path {
          path = "/test"

          backend {
            service {
              name = kubernetes_service.app["foo"].metadata[0].name
              port {
                number = kubernetes_service.app["foo"].spec[0].port[0].port
              }
            }
          }
        }

        path {
          path = "/test"

          backend {
            service {
              name = kubernetes_service.app["bar"].metadata[0].name
              port {
                number = kubernetes_service.app["bar"].spec[0].port[0].port
              }
            }
          }
        }

        path {
          path = "/test"

          backend {
            service {
              name = kubernetes_service.app["boom"].metadata[0].name
              port {
                number = kubernetes_service.app["boom"].spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "app_ingress_canary" {
  for_each = { for app in local.applications.applications : app.name => app }

  metadata {
    name = "${each.value.name}-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/canary" = "true"
      "nginx.ingress.kubernetes.io/canary-weight" = each.value.traffic_weight
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "myapp.local"

      http {
        path {
          path = "/test"

          backend {
            service {
              name = kubernetes_service.app[each.key].metadata[0].name
              port {
                number = kubernetes_service.app[each.key].spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}
