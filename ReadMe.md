# Read Me 

- Project purpose: This repo provides infrastructure as code for a Cribl O11y POV deployment. 
- Architecture overview:
	EKS (FB Sidecar for k8s logs, prometheus, gostatsd metrics) -> Stream -> New Relic, S3, Cribl Lake
	KIND (FB Sidecar for k8s logs, prometheus, gostatsd metrics) -> Stream -> New Relic, S3, Cribl Lake
	Network Device (FB for Syslog) -> Stream -> New Relic, S3, Cribl Lake
- Prequesites: Terraform, kind, kubectl, helm, Cribl Cloud 0Auth2 credentials
- Quick start: terraform init && terraform plan && terraform apply
- Directory layout: 
	Cribl
	EKS
	Kind
- Environment variables:
	EXAMPLE_ENV_VARIABLE

