project_id = "fahman"

region     = "europe-west3"

location   = "europe-west3"

cluster_name = "test-cluster"

min_nodes = 1

max_nodes = 3

vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.0.0/19"
private_subnet_cidr = "10.0.32.0/20"

k8s_namespace = "default"

k8s_service_account = "app-sa"