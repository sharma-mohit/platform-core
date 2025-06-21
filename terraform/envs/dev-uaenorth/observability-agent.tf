module "observability_agent" {
  source = "../../modules/observability-agent"

  workload_cluster_identity_principal_id = module.aks.kubelet_identity_object_id
  central_key_vault_id                  = data.terraform_remote_state.ops.outputs.central_key_vault_id
  environment                           = var.environment
  tags                                  = var.tags
} 