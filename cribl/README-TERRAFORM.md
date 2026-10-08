# Terraform Implementation Notes

## Provider API

The Cribl Terraform provider (`criblio/criblio ~> 1.25`) has specific requirements for resource definitions. The exact schema should be verified against the official Terraform Registry:

https://registry.terraform.io/providers/criblio/criblio/latest/docs

## Configuration Patterns

### JSON-based Configuration

Many Cribl resources (pipelines, destinations, routes) use JSON-encoded configuration. Example:

```hcl
resource "criblio_pipeline" "example" {
  id   = "example-pipeline"
  conf = jsonencode({
    id       = "example-pipeline"
    disabled = false
    functions = [...]
  })
}
```

### File-based References

Configuration files are provided in:
- `pipelines/` - Pipeline JSON definitions
- `destinations/` - Destination YAML definitions  
- `routes.yaml` - Route configuration

These can be incorporated via:

```hcl
content = file("${path.module}/pipelines/normalize.json")
```

## Deployment Workflow

1. **Initialize**: `terraform init`
2. **Validate**: Verify syntax with `terraform validate`
3. **Plan**: Review changes with `terraform plan`
4. **Apply**: Deploy configuration with `terraform apply`
5. **Commit**: Git commit saved in Cribl via `criblio_commit`
6. **Deploy**: Deploy to worker group via `criblio_deploy`

## API Integration

For direct Cribl API calls not covered by Terraform provider, use:

```hcl
resource "null_resource" "cribl_api_call" {
  provisioner "local-exec" {
    command = "curl -X POST ..."
  }
}
```

See `provision.sh` for example integration patterns.

## Testing

```bash
# Syntax validation
terraform validate

# Format check
terraform fmt -check -recursive .

# Format auto-fix
terraform fmt -recursive .

# Dry run
terraform plan -out=tfplan

# Apply (requires valid Cribl credentials)
terraform apply tfplan
```
