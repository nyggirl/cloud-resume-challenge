output "github_actions_plan_role_arn" {
  description = "IAM role used by GitHub Actions for Terraform plans."
  value       = aws_iam_role.github_actions_plan.arn
}