
init-%:
	cd terraform/envs/$* && terraform init

plan-%:
	cd terraform/envs/$* && terraform plan -var-file=terraform.tfvars

apply-%:
	cd terraform/envs/$* && terraform apply -var-file=terraform.tfvars -auto-approve

destroy-%:
	cd terraform/envs/$* && terraform destroy -var-file=terraform.tfvars -auto-approve
