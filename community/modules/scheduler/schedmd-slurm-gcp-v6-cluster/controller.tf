# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  service_account = coalesce(var.service_account, {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  })
}

# INSTANCE TEMPLATE
module "slurm_controller_template" {
  source = "github.com/ek-nag/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_instance_template?ref=controller-ha"

  for_each = {
    for x in var.controller_nodes : x.name_prefix => x
    if(x.instance_template == null || x.instance_template == "")
  }

  project_id          = var.project_id
  slurm_cluster_name  = local.slurm_cluster_name
  slurm_instance_role = "controller"
  slurm_bucket_path   = module.slurm_files.slurm_bucket_path

  additional_disks         = each.value.additional_disks
  bandwidth_tier           = each.value.bandwidth_tier
  can_ip_forward           = each.value.can_ip_forward
  disable_smt              = each.value.disable_smt
  disk_auto_delete         = each.value.disk_auto_delete
  disk_labels              = merge(each.value.disk_labels, local.labels)
  disk_size_gb             = each.value.disk_size_gb
  disk_type                = each.value.disk_type
  enable_confidential_vm   = each.value.enable_confidential_vm
  enable_oslogin           = each.value.enable_oslogin
  enable_shielded_vm       = each.value.enable_shielded_vm
  #gpu                      = one(each.value.guest_accelerator)
  labels                   = each.value.labels
  machine_type             = each.value.machine_type
  metadata                 = each.value.metadata
  min_cpu_platform         = each.value.min_cpu_platform
  on_host_maintenance      = each.value.on_host_maintenance
  preemptible              = each.value.preemptible
  region                   = each.value.region
  service_account          = each.value.service_account
  shielded_instance_config = each.value.shielded_instance_config
  source_image_family      = each.value.source_image_family
  source_image_project     = each.value.source_image_project
  source_image             = each.value.source_image
  # spot = TODO: add support for spot (?)
  subnetwork = each.value.subnetwork
  # network_ip = TODO: add support for network_ip
  tags = concat([local.slurm_cluster_name], each.value.tags)
  # termination_action = TODO: add support for termination_action (?)
}

# INSTANCE
module "slurm_controller_instance" {
  source = "github.com/ek-nag/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_controller_instance?ref=controller-ha"
  for_each = { for x in var.controller_nodes : x.name_prefix => x }

  project_id          = var.project_id
  slurm_cluster_name  = local.slurm_cluster_name

  enable_public_ip = each.value.enable_public_ip
  instance_template = (
    each.value.instance_template != null && each.value.instance_template != ""
    ? each.value.instance_template
    : module.slurm_controller_template[each.key].self_link
  )
  network_tier  = each.value.network_tier
  num_instances = each.value.num_instances

  region              = each.value.region
  static_ips          = each.value.static_ips
  subnetwork          = each.value.subnetwork
  suffix              = each.key
  zone                = each.value.zone
  metadata            = each.value.metadata
  

  depends_on = [
    module.slurm_files,
    # Ensure nodes are destroyed before controller is
    module.cleanup_compute_nodes[0],
  ]
}

# SECRETS: CLOUDSQL
resource "google_secret_manager_secret" "cloudsql" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = "${local.slurm_cluster_name}-slurm-secret-cloudsql"

  replication {
    auto {}
  }

  labels = {
    slurm_cluster_name = local.slurm_cluster_name
  }
}

resource "google_secret_manager_secret_version" "cloudsql_version" {
  count = var.cloudsql != null ? 1 : 0

  secret      = google_secret_manager_secret.cloudsql[0].id
  secret_data = jsonencode(var.cloudsql)
}

resource "google_secret_manager_secret_iam_member" "cloudsql_secret_accessor" {
  count = var.cloudsql != null ? 1 : 0

  secret_id = google_secret_manager_secret.cloudsql[0].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.service_account[0].email}"
}


# Destroy all compute nodes on `terraform destroy`
module "cleanup_compute_nodes" {
  source = "github.com/GoogleCloudPlatform/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_destroy_nodes?ref=6.2.1"
  count  = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = local.slurm_cluster_name
  project_id         = var.project_id
  when_destroy       = true

  # Depend on controller network, as a best effort to avoid
  # subnetwork resourceInUseByAnotherResource error
  # NOTE: Can not use nodeset subnetworks as "A static list expression is required"
  #depends_on = var.controller_nodes != [] ? [module.slurm_controller_instance[var.controller_nodes[0].name_prefix].subnetwork] : []

}


# Destroy all resource policies on `terraform destroy`
module "cleanup_resource_policies" {
  source = "github.com/GoogleCloudPlatform/slurm-gcp.git//terraform/slurm_cluster/modules/slurm_destroy_resource_policies?ref=6.2.1"
  count  = var.enable_cleanup_compute ? 1 : 0

  slurm_cluster_name = local.slurm_cluster_name
  project_id         = var.project_id
  when_destroy       = true
}
