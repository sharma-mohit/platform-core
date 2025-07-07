# module "observability_agent" {
#   source = "../../modules/observability-agent"
# 
#   kubelet_identity_object_id            = module.aks.kubelet_identity_object_id
#   central_key_vault_id                  = data.terraform_remote_state.ops.outputs.central_key_vault_id
#   aks_cluster_name                      = module.aks.cluster_name
#   grafana_workspace_id                  = data.terraform_remote_state.ops.outputs.grafana_workspace_id
#   log_analytics_workspace_id            = data.terraform_remote_state.ops.outputs.log_analytics_workspace_id
#   mimir_remote_write_url                = "https://mimir.ops.example.com/api/v1/push"
#   loki_grpc_url                         = "loki.ops.example.com:9095"
# } 