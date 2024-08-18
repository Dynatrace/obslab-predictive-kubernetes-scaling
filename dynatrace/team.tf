resource "dynatrace_ownership_teams" "demo" {
  name        = var.demo_name_kebab
  identifier  = var.demo_name_kebab
  description = "${var.demo_name} demo team"

  responsibilities {
    development      = true
    infrastructure   = false
    line_of_business = false
    operations       = true
    security         = false
  }
}